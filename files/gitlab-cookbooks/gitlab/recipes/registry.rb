#
# Copyright:: Copyright (c) 2016 GitLab Inc.
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
registry_uid = node['gitlab']['registry']['uid']
registry_gid = node['gitlab']['registry']['gid']

working_dir = node['gitlab']['registry']['dir']
log_directory = node['gitlab']['registry']['log_directory']

directory "create #{working_dir}" do
  path working_dir
  recursive true
end

account "Docker registry user and group" do
  username account_helper.registry_user
  uid registry_uid
  ugid account_helper.registry_group
  groupname account_helper.registry_group
  gid registry_gid
  shell '/bin/sh'
  home working_dir
  manage node['gitlab']['manage-accounts']['enable']
end

[
  working_dir,
  log_directory,
].each do |dir|
  directory "create #{dir} and set the owner" do
    path dir
    owner account_helper.registry_user
    mode '0700'
    recursive true
  end
end

directory node['gitlab']['gitlab-rails']['registry_path'] do
  owner account_helper.registry_user
  group account_helper.gitlab_group
  mode '0750'
  recursive true
  only_if { node['gitlab']['manage-storage-directories']['enable'] }
end

key_file_path = node['gitlab']['gitlab-rails']['registry_key_path']
file key_file_path do
  content node['gitlab']['registry']['internal_key']
  owner account_helper.gitlab_user
  group account_helper.gitlab_group
end

cert_file_path = File.join(working_dir, "gitlab-registry.crt")
node.default['gitlab']['registry']['rootcertbundle'] = cert_file_path
file cert_file_path do
  content node['gitlab']['registry']['internal_certificate']
  owner account_helper.registry_user
  group account_helper.registry_group
end

template "#{working_dir}/config.yml" do
  source "registry-config.yml.erb"
  owner account_helper.registry_user
  variables node['gitlab']['registry'].to_hash.merge(node['gitlab']['gitlab-rails'].to_hash)
  mode "0644"
  notifies :restart, "service[registry]"
end

runit_service 'registry' do
  options({
    :log_directory => log_directory
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitlab']['registry'].to_hash)
end

file File.join(working_dir, "VERSION") do
  content VersionHelper.version("/opt/gitlab/embedded/bin/registry --version")
  notifies :restart, "service[registry]"
end
