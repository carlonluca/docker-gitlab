require "#{base_path}/embedded/service/omnibus-ctl-ee/lib/geo/promote_db"

#
# Copyright:: Copyright (c) 2020 GitLab Inc.
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

add_command_under_category('promote-db', 'gitlab-geo', 'Promote secondary PostgreSQL database', 2) do |cmd_name, *args|
  print_deprecation_message

  Geo::PromoteDb.new(self).execute
end

def print_deprecation_message
  puts
  puts 'WARNING: As of GitLab 14.5, this command is deprecated in favor of ' \
    'gitlab-ctl geo promote. This command will be removed in GitLab 15.0. ' \
    'Please see https://docs.gitlab.com/ee/administration/geo/disaster_recovery/planned_failover.html ' \
    'for more details.'.color(:red)
end
