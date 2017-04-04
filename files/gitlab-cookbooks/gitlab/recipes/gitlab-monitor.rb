#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
gitlab_user = account_helper.gitlab_user
gitlab_monitor_dir = node['gitlab']['gitlab-monitor']['home']
gitlab_monitor_log_dir = node['gitlab']['gitlab-monitor']['log_directory']

directory gitlab_monitor_dir do
  owner gitlab_user
  mode "0755"
  recursive true
end

directory gitlab_monitor_log_dir do
  owner gitlab_user
  mode "0700"
  recursive true
end

redis_url = RedisHelper.new(node).redis_url
template "#{gitlab_monitor_dir}/gitlab-monitor.yml" do
  source "gitlab-monitor.yml.erb"
  owner gitlab_user
  mode "0644"
  notifies :restart, "service[gitlab-monitor]"
  variables(:redis_url => redis_url)
end

runit_service "gitlab-monitor" do
  options({
    log_directory: gitlab_monitor_log_dir
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitlab']['registry'].to_hash)
end

if node['gitlab']['bootstrap']['enable']
  execute "/opt/gitlab/bin/gitlab-ctl start gitlab-monitor" do
    retries 20
  end
end
