#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# Copyright:: Copyright (c) 2016 Gitlab Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
account_helper = AccountHelper.new(node)
postgresql_user = account_helper.postgresql_user
postgres_exporter_env_dir = node['monitoring']['postgres_exporter']['env_directory']
postgres_exporter_dir = node['monitoring']['postgres_exporter']['home']
postgres_exporter_sslmode = " sslmode=#{node['monitoring']['postgres_exporter']['sslmode']}" \
  unless node['monitoring']['postgres_exporter']['sslmode'].nil?
logfiles_helper = LogfilesHelper.new(node)
logging_settings = logfiles_helper.logging_settings('postgres-exporter')
postgres_exporter_connection_string = if node['postgresql']['enable']
                                        "host=#{node['postgresql']['dir']} user=#{node['postgresql']['username']}"
                                      else
                                        "host=#{node['gitlab']['gitlab_rails']['db_host']} " \
                                        "port=#{node['gitlab']['gitlab_rails']['db_port']} " \
                                        "user=#{node['gitlab']['gitlab_rails']['db_username']} "\
                                        "password=#{node['gitlab']['gitlab_rails']['db_password']}"
                                      end
postgres_exporter_database = "#{node['gitlab']['gitlab_rails']['db_database']}#{postgres_exporter_sslmode}"

node.default['monitoring']['postgres_exporter']['env']['DATA_SOURCE_NAME'] = "#{postgres_exporter_connection_string} " \
                                                                             "database=#{postgres_exporter_database}"
deprecated_per_table_stats = node['monitoring']['postgres_exporter']['per_table_stats']
node.override['monitoring']['postgres_exporter']['flags']['collector.stat_user_tables'] = deprecated_per_table_stats unless deprecated_per_table_stats.nil?
include_recipe 'postgresql::user'

# Create log_directory
directory logging_settings[:log_directory] do
  owner logging_settings[:log_directory_owner]
  mode logging_settings[:log_directory_mode]
  if log_group = logging_settings[:log_directory_group]
    group log_group
  end
  recursive true
end

directory postgres_exporter_dir do
  owner postgresql_user
  mode '0700'
  recursive true
end

env_dir postgres_exporter_env_dir do
  variables node['monitoring']['postgres_exporter']['env']
  notifies :restart, "runit_service[postgres-exporter]"
end

runtime_flags = PrometheusHelper.new(node).kingpin_flags('postgres_exporter')
runit_service 'postgres-exporter' do
  options({
    log_directory: logging_settings[:log_directory],
    log_user: logging_settings[:runit_owner],
    log_group: logging_settings[:runit_group],
    flags: runtime_flags,
    env_dir: postgres_exporter_env_dir
  }.merge(params))
  log_options logging_settings[:options]
end

template File.join(postgres_exporter_dir, 'queries.yaml') do
  source 'postgres-queries.yaml.erb'
  owner postgresql_user
  mode '0644'
  notifies :restart, 'runit_service[postgres-exporter]'
end

if node['gitlab']['bootstrap']['enable']
  execute "/opt/gitlab/bin/gitlab-ctl start postgres-exporter" do
    retries 20
  end
end

consul_service node['monitoring']['postgres_exporter']['consul_service_name'] do
  id 'postgres-exporter'
  meta node['monitoring']['postgres_exporter']['consul_service_meta']
  action Prometheus.service_discovery_action
  socket_address node['monitoring']['postgres_exporter']['listen_address']
  reload_service false unless Services.enabled?('consul')
end
