#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# Copyright:: Copyright (c) 2017 GitLab Inc.
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
omnibus_helper = OmnibusHelper.new(node)
gitlab_geo_helper = GitlabGeoHelper.new(node)

postgresql_dir = node['gitlab']['geo-postgresql']['dir']
postgresql_data_dir = node['gitlab']['geo-postgresql']['data_dir']
postgresql_data_dir_symlink = File.join(postgresql_dir, 'data')
postgresql_log_dir = node['gitlab']['geo-postgresql']['log_directory']
postgresql_socket_dir = node['gitlab']['geo-postgresql']['unix_socket_directory']
postgresql_username = account_helper.postgresql_user

geo_pg_helper = GeoPgHelper.new(node)
fdw_helper = FdwHelper.new(node)

include_recipe 'postgresql::user'

directory postgresql_dir do
  owner postgresql_username
  mode '0755'
  recursive true
end

[
  postgresql_data_dir,
  postgresql_log_dir
].each do |dir|
  directory dir do
    owner postgresql_username
    mode '0700'
    recursive true
  end
end

link postgresql_data_dir_symlink do
  to postgresql_data_dir
  not_if { postgresql_data_dir == postgresql_data_dir_symlink }
end

execute "/opt/gitlab/embedded/bin/initdb -D #{postgresql_data_dir} -E UTF8" do
  user postgresql_username
  not_if { geo_pg_helper.bootstrapped? }
end

postgresql_config = File.join(postgresql_data_dir, 'postgresql.conf')
postgresql_runtime_config = File.join(postgresql_data_dir, 'runtime.conf')
bootstrapping = !geo_pg_helper.bootstrapped?
should_notify = omnibus_helper.should_notify?('geo-postgresql') && !bootstrapping

template postgresql_config do
  source 'postgresql.conf.erb'
  owner postgresql_username
  mode '0644'
  helper(:pg_helper) { geo_pg_helper }
  variables(node['gitlab']['geo-postgresql'].to_hash)
  cookbook 'postgresql'
  notifies :restart, 'service[geo-postgresql]', :immediately if should_notify
end

template postgresql_runtime_config do
  source 'postgresql-runtime.conf.erb'
  owner postgresql_username
  mode '0644'
  helper(:pg_helper) { geo_pg_helper }
  variables(node['gitlab']['geo-postgresql'].to_hash)
  cookbook 'postgresql'
  notifies :run, 'execute[reload geo-postgresql]', :immediately if should_notify
end

pg_hba_config = File.join(postgresql_data_dir, 'pg_hba.conf')

template pg_hba_config do
  source 'pg_hba.conf.erb'
  owner postgresql_username
  mode '0644'
  variables(lazy { node['gitlab']['geo-postgresql'].to_hash })
  cookbook 'postgresql'
  notifies :restart, 'service[geo-postgresql]', :immediately if should_notify
end

template File.join(postgresql_data_dir, 'pg_ident.conf') do
  owner postgresql_username
  mode '0644'
  variables(node['gitlab']['geo-postgresql'].to_hash)
  cookbook 'postgresql'
  notifies :restart, 'service[geo-postgresql]', :immediately if should_notify
end

runit_service 'geo-postgresql' do
  down node['gitlab']['geo-postgresql']['ha']
  control(['t'])
  options({
    log_directory: postgresql_log_dir
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitlab']['geo-postgresql'].to_hash)
end

# This recipe must be ran BEFORE any calls to the binaries are made
# and AFTER the service has been defined
# to ensure the correct running version of PostgreSQL
# Only exception to this rule is "initdb" call few lines up because this should
# run only on new installation at which point we expect to have correct binaries.
include_recipe 'postgresql::bin'

execute 'start geo-postgresql' do
  command '/opt/gitlab/bin/gitlab-ctl start geo-postgresql'
  retries 20
  action :nothing unless bootstrapping
end

###
# Create the database, migrate it, and create the users we need, and grant them
# privileges.
###

# This template is needed to make the gitlab-geo-psql script and GeoPgHelper work
template '/opt/gitlab/etc/gitlab-geo-psql-rc' do
  owner 'root'
  group 'root'
end

geo_pg_port = node['gitlab']['geo-postgresql']['port']
geo_pg_user = node['gitlab']['geo-postgresql']['sql_user']
geo_database_name = node['gitlab']['geo-secondary']['db_database']

# Foreign Data Wrapper specific (credentials for the secondary - readonly pg instance)
fdw_user = node['gitlab']['geo-postgresql']['fdw_external_user']
fdw_password = node['gitlab']['geo-postgresql']['fdw_external_password']

fdw_host = node['gitlab']['gitlab-rails']['db_host']
fdw_port = node['gitlab']['gitlab-rails']['db_port']
fdw_dbname = node['gitlab']['gitlab-rails']['db_database']

if node['gitlab']['geo-postgresql']['enable']
  postgresql_user geo_pg_user do
    helper geo_pg_helper
    action :create
  end

  execute "create #{geo_database_name} database" do
    command "/opt/gitlab/embedded/bin/createdb --port #{geo_pg_port} -h #{postgresql_socket_dir} -O #{geo_pg_user} #{geo_database_name}"
    user postgresql_username
    retries 30
    not_if { !geo_pg_helper.is_running? || geo_pg_helper.database_exists?(geo_database_name) }
  end

  postgresql_extension 'pg_trgm' do
    database geo_database_name
    helper geo_pg_helper
    action :enable
  end

  postgresql_query 'create gitlab_secondary schema on geo-postgresql' do
    query "CREATE SCHEMA gitlab_secondary;"
    db_name geo_database_name
    helper geo_pg_helper
    action :run

    not_if { !fdw_helper.fdw_enabled? || geo_pg_helper.is_offline_or_readonly? || geo_pg_helper.schema_exists?('gitlab_secondary', geo_database_name) }
  end

  postgresql_fdw 'gitlab_secondary' do
    db_name geo_database_name
    external_host fdw_host
    external_port fdw_port
    external_name fdw_dbname
    helper geo_pg_helper
    action :create
    only_if { fdw_helper.fdw_enabled? && fdw_password }
  end

  postgresql_fdw_user_mapping 'gitlab_secondary' do
    db_user geo_pg_user
    db_name geo_database_name
    external_user fdw_user
    external_password fdw_password
    helper geo_pg_helper
    action :create
    only_if { fdw_helper.fdw_enabled? && fdw_password }
  end

  bash 'refresh foreign table definition' do
    code <<-EOF
      umask 077
      function safeRun() {
        /opt/gitlab/bin/gitlab-rake geo:db:refresh_foreign_tables
        STATUS=$?
        echo $STATUS > #{gitlab_geo_helper.fdw_sync_status_file}
      }
      safeRun # we always return 0 so we don't block reconfigure flow
    EOF

    only_if { fdw_helper.fdw_can_refresh? }
  end
end

execute 'reload geo-postgresql' do
  command %(/opt/gitlab/bin/gitlab-ctl hup geo-postgresql)
  retries 20
  action :nothing
  only_if { geo_pg_helper.is_running? }
end

execute 'start geo-postgresql again' do
  command %(/opt/gitlab/bin/gitlab-ctl start geo-postgresql)
  retries 20
  action :nothing
  not_if { geo_pg_helper.is_running? }
end
