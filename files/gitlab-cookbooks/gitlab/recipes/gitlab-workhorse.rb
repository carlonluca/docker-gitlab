#
# Copyright:: Copyright (c) 2015 GitLab B.V.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
account_helper = AccountHelper.new(node)
redis_helper = RedisHelper.new(node)
workhorse_helper = GitlabWorkhorseHelper.new(node)

working_dir = node['gitlab']['gitlab-workhorse']['dir']
log_directory = node['gitlab']['gitlab-workhorse']['log_directory']
gitlab_workhorse_static_etc_dir = "/opt/gitlab/etc/gitlab-workhorse"
workhorse_env_dir = node['gitlab']['gitlab-workhorse']['env_directory']
gitlab_workhorse_socket_dir = node['gitlab']['gitlab-workhorse']['sockets_directory']

directory working_dir do
  owner account_helper.gitlab_user
  group account_helper.web_server_group
  mode '0750'
  recursive true
end

if workhorse_helper.unix_socket? && !gitlab_workhorse_socket_dir.nil?
  directory gitlab_workhorse_socket_dir do
    owner account_helper.gitlab_user
    group account_helper.web_server_group
    mode '0750'
    notifies :restart, "runit_service[gitlab-workhorse]"
    recursive true
  end
end

directory log_directory do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

directory gitlab_workhorse_static_etc_dir do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

env_dir workhorse_env_dir do
  variables node['gitlab']['gitlab-workhorse']['env']
  notifies :restart, "runit_service[gitlab-workhorse]"
end

runit_service 'gitlab-workhorse' do
  start_down node['gitlab']['gitlab-workhorse']['ha']
  options({
    log_directory: log_directory
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitlab']['gitlab-workhorse'].to_hash)
end

consul_service node['gitlab']['gitlab-workhorse']['consul_service_name'] do
  id 'workhorse'
  action Prometheus.service_discovery_action
  socket_address node['gitlab']['gitlab-workhorse']['prometheus_listen_addr']
  reload_service false unless node['consul']['enable']
end

version_file 'Create version file for Workhorse' do
  version_file_path File.join(working_dir, 'VERSION')
  version_check_cmd '/opt/gitlab/embedded/bin/gitlab-workhorse --version'
  notifies :restart, "runit_service[gitlab-workhorse]"
end

alt_document_root = node['gitlab']['gitlab-workhorse']['alt_document_root']
shutdown_timeout = node['gitlab']['gitlab-workhorse']['shutdown_timeout']
_redis_host, _redis_port, redis_password = redis_helper.redis_params
workhorse_keywatcher = node['gitlab']['gitlab-workhorse']['workhorse_keywatcher']
redis_url = redis_helper.redis_url.to_s
redis_sentinels = node['gitlab']['gitlab-rails']['redis_sentinels']
redis_sentinel_master = node['redis']['master_name']
redis_sentinel_master_password = node['redis']['master_password']
config_file_path = File.join(working_dir, "config.toml")
object_store = node['gitlab']['gitlab-rails']['object_store']
provider = object_store.dig('connection', 'provider')
object_store_provider = provider if %w(AWS AzureRM).include?(provider)
image_scaler_max_procs = node['gitlab']['gitlab-workhorse']['image_scaler_max_procs']
image_scaler_max_filesize = node['gitlab']['gitlab-workhorse']['image_scaler_max_filesize']
trusted_cidrs_for_propagation = node['gitlab']['gitlab-workhorse']['trusted_cidrs_for_propagation']
trusted_cidrs_for_x_forwarded_for = node['gitlab']['gitlab-workhorse']['trusted_cidrs_for_x_forwarded_for']

template config_file_path do
  source "workhorse-config.toml.erb"
  owner "root"
  group account_helper.gitlab_group
  mode "0640"
  variables(
    alt_document_root: alt_document_root,
    object_store: object_store,
    object_store_provider: object_store_provider,
    workhorse_keywatcher: workhorse_keywatcher,
    redis_url: redis_url,
    password: redis_password,
    sentinels: redis_sentinels,
    sentinel_master: redis_sentinel_master,
    shutdown_timeout: shutdown_timeout,
    master_password: redis_sentinel_master_password,
    image_scaler_max_procs: image_scaler_max_procs,
    image_scaler_max_filesize: image_scaler_max_filesize,
    trusted_cidrs_for_propagation: trusted_cidrs_for_propagation,
    trusted_cidrs_for_x_forwarded_for: trusted_cidrs_for_x_forwarded_for
  )
  notifies :restart, "runit_service[gitlab-workhorse]"
  notifies :run, 'bash[Set proper security context on ssh files for selinux]', :delayed if SELinuxHelper.enabled?
end
