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

module Postgresql
  class << self
    def parse_variables
      parse_postgresql_settings
      parse_multi_db_host_addresses
      parse_mattermost_postgresql_settings
    end

    def parse_postgresql_settings
      # If the user wants to run the internal Postgres service using an alternative
      # DB username, host or port, then those settings should also be applied to
      # gitlab-rails and gitlab-ci.
      [
        # %w{gitlab_rails db_username} corresponds to
        # Gitlab['gitlab_rails']['db_username'], etc.
        [%w{gitlab_rails db_username}, %w{postgresql sql_user}],
        [%w{gitlab_rails db_host}, %w{postgresql listen_address}],
        [%w{gitlab_rails db_port}, %w{postgresql port}],
        [%w{gitlab_ci db_username}, %w{postgresql sql_ci_user}],
        [%w{gitlab_ci db_host}, %w{postgresql listen_address}],
        [%w{gitlab_ci db_port}, %w{postgresql port}],
      ].each do |left, right|
        if ! Gitlab[left.first][left.last].nil?
          # If the user explicitly sets a value for e.g.
          # gitlab_rails['db_port'] in gitlab.rb then we should never override
          # that.
          next
        end

        better_value_from_gitlab_rb = Gitlab[right.first][right.last]
        default_from_attributes = Gitlab['node']['gitlab'][right.first.gsub('_', '-')][right.last]
        Gitlab[left.first][left.last] = better_value_from_gitlab_rb || default_from_attributes
      end
    end

    def parse_multi_db_host_addresses
      # Postgres allow multiple listen addresses, comma-separated values
      # In case of multi listen_address, will use the first address from list
      db_host = Gitlab['gitlab_rails']['db_host']
      return if db_host.nil?

      if db_host.include?(',')
        Gitlab['gitlab_rails']['db_host'] = db_host.split(',')[0]
        warning = [
          "Received gitlab_rails['db_host'] value was: #{db_host.to_json}.",
          "First listen_address '#{Gitlab['gitlab_rails']['db_host']}' will be used."
        ].join("\n  ")
        warn(warning)
      end
    end

    def parse_mattermost_postgresql_settings
      value_from_gitlab_rb = Gitlab['mattermost']['sql_data_source']

      attributes_values = []
      [
        %w{postgresql sql_mattermost_user},
        %w{postgresql unix_socket_directory},
        %w{postgresql port},
        %w{mattermost database_name}
      ].each do |value|
        attributes_values << (Gitlab[value.first][value.last] || Gitlab['node']['gitlab'][value.first][value.last])
      end

      value_from_attributes = "user=#{attributes_values[0]} host=#{attributes_values[1]} port=#{attributes_values[2]} dbname=#{attributes_values[3]}"
      Gitlab['mattermost']['sql_data_source'] = value_from_gitlab_rb || value_from_attributes

      if Gitlab['mattermost']['sql_data_source_replicas'].nil? && Gitlab['node']['gitlab']['mattermost']['sql_data_source_replicas'].empty?
        Gitlab['mattermost']['sql_data_source_replicas'] = [Gitlab['mattermost']['sql_data_source']]
      end
    end
  end
end
