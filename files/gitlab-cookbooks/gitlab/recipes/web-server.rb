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

account_helper = AccountHelper.new(node)
webserver_username = account_helper.web_server_user
webserver_group = account_helper.web_server_group
external_webserver_users = node['gitlab']['web-server']['external_users'].to_a

# This recipe runs before registry recipe so we need to make sure that the
# registry users is appended to the webserver group as registry requires access
# to the gitlab-rails/shared folder.
# Without this check the reconfigure run would fail on the first run and also
# the group would end up being altered on every reconfigure run
if node["gitlab"]["registry"]["enable"] && OmnibusHelper.user_exists?(account_helper.registry_user)
  external_webserver_users << account_helper.registry_user
end

# Create the group for the GitLab user
# If external webserver is used, add the external webserver user to
# GitLab webserver group

account "Webserver user and group" do
  username webserver_username
  uid node['gitlab']['web-server']['uid']
  ugid webserver_group
  groupname webserver_group
  gid node['gitlab']['web-server']['gid']
  shell node['gitlab']['web-server']['shell']
  home node['gitlab']['web-server']['home']
  append_to_group external_webserver_users.any?
  group_members external_webserver_users
  user_supports manage_home: false
  manage node['gitlab']['manage-accounts']['enable']
end
