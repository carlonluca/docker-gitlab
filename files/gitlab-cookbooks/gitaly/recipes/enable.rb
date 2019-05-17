#
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

working_dir = node['gitaly']['dir']
log_directory = node['gitaly']['log_directory']
env_directory = node['gitaly']['env_directory']
config_path = File.join(working_dir, "config.toml")
gitaly_path = node['gitaly']['bin_path']
wrapper_path = "#{gitaly_path}-wrapper"
pid_file = File.join(working_dir, "gitaly.pid")
json_logging = node['gitaly']['logging_format'].eql?('json')

directory working_dir do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

directory log_directory do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

# Doing this in attributes/default.rb will need gitlab cookbook to be loaded
# before gitaly cookbook. This means gitaly cookbook has to depend on gitlab
# cookbook.  Since gitlab cookbook already depends on gitaly cookbook, this
# causes a circular dependency. To avoid it, the default value is set in the
# recipe itself.
node.default['gitaly']['env'] = {
  'HOME' => node['gitlab']['user']['home'],
  'PATH' => "#{node['package']['install-dir']}/bin:#{node['package']['install-dir']}/embedded/bin:/bin:/usr/bin",
  'TZ' => ':/etc/localtime',
  # This is needed by gitlab-markup to import Python docutils
  'PYTHONPATH' => "#{node['package']['install-dir']}/embedded/lib/python3.7/site-packages",
  # Charlock Holmes and libicu will report U_FILE_ACCESS_ERROR if this is not set to the right path
  # See https://gitlab.com/gitlab-org/gitlab-ce/issues/17415#note_13868167
  'ICU_DATA' => "#{node['package']['install-dir']}/embedded/share/icu/current",
  'SSL_CERT_DIR' => "#{node['package']['install-dir']}/embedded/ssl/certs/",
  # wrapper script parameters
  'GITALY_PID_FILE' => pid_file,
  'WRAPPER_JSON_LOGGING' => json_logging.to_s
}

env_dir env_directory do
  variables node['gitaly']['env']
  notifies :restart, "service[gitaly]"
end

# Before version 11.6, gitaly env directory was `/opt/gitlab/etc/gitaly` by
# default. With 11.6, we changed it to `/opt/gitlab/etc/gitaly/env`. We attempt
# to clean the old files if user is using the default location.
# TODO: Drop this in 12.0
node['gitaly']['env'].keys.each do |item|
  file File.join("/opt/gitlab/etc/gitaly", item) do
    action :delete
    only_if { node['gitaly']['env_directory'] == '/opt/gitlab/etc/gitaly/env' }
  end
end

template "Create Gitaly config.toml" do
  path config_path
  source "gitaly-config.toml.erb"
  owner "root"
  group account_helper.gitlab_group
  mode "0640"
  variables node['gitaly'].to_hash
  notifies :hup, "runit_service[gitaly]"
end

runit_service 'gitaly' do
  down node['gitaly']['ha']
  options({
    user: account_helper.gitlab_user,
    groupname: account_helper.gitlab_group,
    working_dir: working_dir,
    env_dir: env_directory,
    bin_path: gitaly_path,
    wrapper_path: wrapper_path,
    config_path: config_path,
    log_directory: log_directory,
    json_logging: json_logging
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitaly'].to_hash)
end

if node['gitlab']['bootstrap']['enable']
  execute "/opt/gitlab/bin/gitlab-ctl start gitaly" do
    retries 20
  end
end

file File.join(working_dir, "VERSION") do
  content VersionHelper.version("/opt/gitlab/embedded/bin/gitaly --version")
  notifies :hup, "runit_service[gitaly]"
end
