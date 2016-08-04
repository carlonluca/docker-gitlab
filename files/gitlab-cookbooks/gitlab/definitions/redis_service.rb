#
# Copyright:: Copyright (c) 2014 GitLab B.V.
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

define :redis_service, :socket_group => nil do
  svc = params[:name]

  redis_dir = node['gitlab'][svc]['dir']
  redis_log_dir = node['gitlab'][svc]['log_directory']
  redis_user = AccountHelper.new(node).redis_user

  account "Redis user and group" do
    username redis_user
    uid node['gitlab'][svc]['uid']
    ugid redis_user
    groupname redis_user
    gid node['gitlab'][svc]['gid']
    shell  node['gitlab'][svc]['shell']
    home node['gitlab'][svc]['home']
    manage node['gitlab']['manage-accounts']['enable']
  end

  directory redis_dir do
    owner redis_user
    group params[:socket_group]
    mode "0750"
  end

  directory redis_log_dir do
    owner redis_user
    mode "0700"
  end

  redis_config = File.join(redis_dir, "redis.conf")

  template redis_config do
    source "redis.conf.erb"
    owner redis_user
    mode "0644"
    variables(node['gitlab'][svc].to_hash)
    notifies :restart, "service[#{svc}]", :immediately if OmnibusHelper.should_notify?(svc)
  end

  runit_service svc do
    down node['gitlab'][svc]['ha']
    template_name 'redis'
    options({
      :service => svc,
      :log_directory => redis_log_dir
    }.merge(params))
    log_options node['gitlab']['logging'].to_hash.merge(node['gitlab'][svc].to_hash)
  end

  if node['gitlab']['bootstrap']['enable']
    execute "/opt/gitlab/bin/gitlab-ctl start #{svc}" do
      retries 20
    end
  end
end
