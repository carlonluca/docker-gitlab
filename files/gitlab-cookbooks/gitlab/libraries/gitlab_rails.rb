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

require_relative 'nginx.rb'

module GitlabRails
  class << self
    def parse_variables
      parse_external_url
      parse_directories
      parse_gitlab_trusted_proxies
    end

    def parse_directories
      parse_git_data_dirs
      parse_shared_dir
      parse_artifacts_dir
      parse_lfs_objects_dir
      parse_pages_dir
    end

    def parse_external_url
      return unless Gitlab['external_url']

      uri = URI(Gitlab['external_url'].to_s)

      unless uri.host
        raise "GitLab external URL must include a schema and FQDN, e.g. http://gitlab.example.com/"
      end
      Gitlab['user']['git_user_email'] ||= "gitlab@#{uri.host}"
      Gitlab['gitlab_rails']['gitlab_host'] = uri.host
      Gitlab['gitlab_rails']['gitlab_email_from'] ||= "gitlab@#{uri.host}"
      Gitlab['nginx']['proxy_set_headers'] ||= Hash.new
      Gitlab['nginx']['proxy_set_headers']['Host'] ||= "#{uri.host}:#{uri.port}"

      case uri.scheme
      when "http"
        Gitlab['gitlab_rails']['gitlab_https'] = false
        Nginx.parse_proxy_headers('nginx', false)
      when "https"
        Gitlab['gitlab_rails']['gitlab_https'] = true
        Gitlab['nginx']['ssl_certificate'] ||= "/etc/gitlab/ssl/#{uri.host}.crt"
        Gitlab['nginx']['ssl_certificate_key'] ||= "/etc/gitlab/ssl/#{uri.host}.key"
        Nginx.parse_proxy_headers('nginx', true)
      else
        raise "Unsupported external URL scheme: #{uri.scheme}"
      end

      unless ["", "/"].include?(uri.path)
        relative_url = uri.path.chomp("/")
        Gitlab['gitlab_rails']['gitlab_relative_url'] ||= relative_url
        Gitlab['unicorn']['relative_url'] ||= relative_url
        Gitlab['gitlab_workhorse']['relative_url'] ||= relative_url
      end

      Gitlab['gitlab_rails']['gitlab_port'] = uri.port
    end

    def parse_git_data_dirs
      git_data_dirs = Gitlab['git_data_dirs']
      git_data_dir = Gitlab['git_data_dir']
      return unless git_data_dirs.any? || git_data_dir

      Gitlab['gitlab_shell']['git_data_directories'] ||=
        if git_data_dirs.any?
          git_data_dirs
        else
          { 'default' => git_data_dir }
        end

      Gitlab['gitlab_rails']['repositories_storages'] ||=
        Hash[Gitlab['gitlab_shell']['git_data_directories'].map do |name, path|
          [name, File.join(path, 'repositories')]
        end]

      # Important: keep the satellites.path setting until GitLab 9.0 at
      # least. This setting is fed to 'rm -rf' in
      # db/migrate/20151023144219_remove_satellites.rb
      Gitlab['gitlab_rails']['satellites_path'] ||= File.join(Gitlab['gitlab_shell']['git_data_directories']['default'], "gitlab-satellites")
    end

    def parse_shared_dir
      Gitlab['gitlab_rails']['shared_path'] ||= Gitlab['node']['gitlab']['gitlab-rails']['shared_path']
    end

    def parse_artifacts_dir
      # This requires the parse_shared_dir to be executed before
      Gitlab['gitlab_rails']['artifacts_path'] ||= File.join(Gitlab['gitlab_rails']['shared_path'], 'artifacts')
    end

    def parse_lfs_objects_dir
      # This requires the parse_shared_dir to be executed before
      Gitlab['gitlab_rails']['lfs_storage_path'] ||= File.join(Gitlab['gitlab_rails']['shared_path'], 'lfs-objects')
    end

    def parse_pages_dir
      # This requires the parse_shared_dir to be executed before
      Gitlab['gitlab_rails']['pages_path'] ||= File.join(Gitlab['gitlab_rails']['shared_path'], 'pages')
    end

    def parse_gitlab_trusted_proxies
      Gitlab['nginx']['real_ip_trusted_addresses'] ||= Gitlab['node']['gitlab']['nginx']['real_ip_trusted_addresses']
      Gitlab['gitlab_rails']['trusted_proxies'] ||= Gitlab['nginx']['real_ip_trusted_addresses']
    end

    def disable_gitlab_rails_services
      if Gitlab['gitlab_rails']["enable"] == false
        Gitlab['redis']["enable"] = false
        Gitlab['unicorn']["enable"] = false
        Gitlab['sidekiq']["enable"] = false
        Gitlab['gitlab_workhorse']["enable"] = false
      end
    end
  end
end
