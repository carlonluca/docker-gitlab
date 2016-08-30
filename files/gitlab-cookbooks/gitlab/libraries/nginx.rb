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

module Nginx
  class << self
    def parse_variables
      parse_nginx_listen_address
      parse_nginx_listen_ports
    end

    def parse_nginx_listen_address
      return unless Gitlab['nginx']['listen_address']

      # The user specified a custom NGINX listen address with the legacy
      # listen_address option. We have to convert it to the new
      # listen_addresses setting.
      Chef::Log.warn "nginx['listen_address'] is deprecated. Please use nginx['listen_addresses']"
      Gitlab['nginx']['listen_addresses'] = [Gitlab['nginx']['listen_address']]
    end

    def parse_nginx_listen_ports
      [
        [%w{nginx listen_port}, %w{gitlab_rails gitlab_port}],
        [%w{ci_nginx listen_port}, %w{gitlab_ci gitlab_ci_port}],
        [%w{mattermost_nginx listen_port}, %w{mattermost port}],
        [%w{pages_nginx listen_port}, %w{gitlab_rails pages_port}],

      ].each do |left, right|
        if !Gitlab[left.first][left.last].nil?
          next
        end

        default_set_gitlab_port = Gitlab['node']['gitlab'][right.first.gsub('_', '-')][right.last]
        user_set_gitlab_port = Gitlab[right.first][right.last]

        Gitlab[left.first][left.last] = user_set_gitlab_port || default_set_gitlab_port
      end
    end

    def parse_proxy_headers(app, https)
      values_from_gitlab_rb = Gitlab[app]['proxy_set_headers']
      default_from_attributes = Gitlab['node']['gitlab'][app.gsub('_', '-')]['proxy_set_headers'].to_hash

      default_from_attributes = if https
                                  default_from_attributes.merge({
                                                                 'X-Forwarded-Proto' => "https",
                                                                 'X-Forwarded-Ssl' => "on"
                                                               })
                                else
                                  default_from_attributes.merge({
                                                                 "X-Forwarded-Proto" => "http"
                                                               })
                                end

      if values_from_gitlab_rb
        values_from_gitlab_rb.each do |key, value|
          default_from_attributes.delete(key) if value.nil?
        end

        default_from_attributes = default_from_attributes.merge(values_from_gitlab_rb.to_hash)
      end

      Gitlab[app]['proxy_set_headers'] = default_from_attributes
    end

    def parse_error_pages
      # At the least, provide error pages for 404, 402, 500, 502 errors
      errors = Hash[%w(404 422 500 502).map {|x| [x, "#{x}.html"]}]
      if Gitlab['nginx'].key?('custom_error_pages')
        Gitlab['nginx']['custom_error_pages'].each_key do |err|
          errors[err] = "#{err}-custom.html"
        end
      end
      errors
    end
  end
end
