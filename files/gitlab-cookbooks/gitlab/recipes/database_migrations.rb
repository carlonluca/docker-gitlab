#
# Copyright:: Copyright (c) 2014 GitLab.com
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
require 'digest'

omnibus_helper = OmnibusHelper.new(node)
migration_helper = RailsMigrationHelper.new(node)

initial_root_password = node['gitlab']['gitlab-rails']['initial_root_password']
initial_license_file = node['gitlab']['gitlab-rails']['initial_license_file'] || Dir.glob('/etc/gitlab/*.gitlab-license').first
initial_runner_token = node['gitlab']['gitlab-rails']['initial_shared_runners_registration_token']

dependent_services = []
dependent_services << "runit_service[puma]" if omnibus_helper.should_notify?("puma")
dependent_services << "sidekiq_service[sidekiq]" if omnibus_helper.should_notify?("sidekiq")

env_variables = {}
env_variables['GITLAB_ROOT_PASSWORD'] = initial_root_password if initial_root_password
env_variables['GITLAB_LICENSE_FILE'] = initial_license_file if initial_license_file
env_variables['GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN'] = initial_runner_token if initial_runner_token

ruby_block "check remote PG version" do
  block do
    remote_db_version = GitlabRailsEnvHelper.db_version
    if remote_db_version && remote_db_version.to_f < 12
      LoggingHelper.warning(%q(
        Note that PostgreSQL 12 is the minimum required PostgreSQL version in GitLab 14.0.
        Support for PostgreSQL 11 has been removed.
        To upgrade, please see: https://docs.gitlab.com/omnibus/settings/database.html#upgrade-packaged-postgresql-server
      ))
    end
  end

  action :nothing
  only_if { !Services.enabled?('postgresql') && !Services.enabled?('patroni') }
end

rails_migration "gitlab-rails" do
  rake_task 'gitlab:db:configure'
  logfile_prefix 'gitlab-rails-db-migrate'
  helper migration_helper

  environment env_variables
  dependent_services dependent_services
  notifies :run, "execute[clear the gitlab-rails cache]", :immediately
  notifies :run, "ruby_block[check remote PG version]", :immediately

  only_if { migration_helper.attributes_node['auto_migrate'] }
end
