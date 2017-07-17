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

include_recipe 'gitlab::default'

[
  'sentinel',
  'sidekiq-cluster',
  'geo-postgresql',
  'geo-logcursor',
  'pgbouncer'
].each do |service|
  if node['gitlab'][service]['enable']
    include_recipe "gitlab-ee::#{service}"
  else
    include_recipe "gitlab-ee::#{service}_disable"
  end
end

%w(
  repmgr
).each do |service|
  if node[service]['enable']
    include_recipe "#{service}::enable"
  else
    include_recipe "#{service}::disable"
  end
end

include_recipe 'gitlab-ee::ssh_keys'

# Geo secondary
if node['gitlab']['geo-postgresql']['enable']
  include_recipe 'gitlab-ee::geo-secondary'
  include_recipe 'gitlab-ee::geo_database_migrations'
end

# pgbouncer_user and pgbouncer_user_password are settings for the account
# pgbouncer will use to authenticate to the database.
if node['gitlab']['postgresql']['enable'] &&
    !node['gitlab']['postgresql']['pgbouncer_user'].nil? &&
    !node['gitlab']['postgresql']['pgbouncer_user_password'].nil?
  include_recipe 'gitlab-ee::pgbouncer_user'
end
