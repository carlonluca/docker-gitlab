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
require_relative 'gitaly.rb'

module GitlabRails
  class << self
    def parse_variables
      handle_legacy_variables

      parse_external_url
      parse_directories
      parse_gitlab_trusted_proxies
      parse_rack_attack_protected_paths
      parse_gitaly_variables
    end

    def parse_directories
      parse_runtime_dir
      parse_shared_dir
      parse_artifacts_dir
      parse_lfs_objects_dir
      parse_pages_dir
      parse_repository_storage
    end

    def parse_secrets
      # Blow up when the existing configuration is ambiguous, so we don't accidentally throw away important secrets
      ci_db_key_base = Gitlab['gitlab_ci']['db_key_base']
      rails_db_key_base = Gitlab['gitlab_rails']['db_key_base']

      if ci_db_key_base && rails_db_key_base && ci_db_key_base != rails_db_key_base
        message = [
          "The value of Gitlab['gitlab_ci']['db_key_base'] (#{ci_db_key_base}) does not match the value of Gitlab['gitlab_rails']['db_key_base'] (#{rails_db_key_base}).",
          "Please back up both secrets, set Gitlab['gitlab_rails']['db_key_base'] to the value of Gitlab['gitlab_ci']['db_key_base'], and try again.",
          "For more information, see <https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/update/README.md#migrating-legacy-secrets>"
        ]

        raise message.join("\n\n")
      end

      # Transform legacy key names to new key names
      Gitlab['gitlab_rails']['db_key_base'] ||= Gitlab['gitlab_ci']['db_key_base'] # Changed in 8.11
      Gitlab['gitlab_rails']['secret_key_base'] ||= Gitlab['gitlab_ci']['db_key_base'] # Changed in 8.11
      Gitlab['gitlab_rails']['otp_key_base'] ||= Gitlab['gitlab_rails']['secret_token']

      # Note: If you add another secret to generate here make sure it gets written to disk in SecretsHelper.write_to_gitlab_secrets
      Gitlab['gitlab_rails']['db_key_base'] ||= SecretsHelper.generate_hex(64)
      Gitlab['gitlab_rails']['secret_key_base'] ||= SecretsHelper.generate_hex(64)
      Gitlab['gitlab_rails']['otp_key_base'] ||= SecretsHelper.generate_hex(64)
      Gitlab['gitlab_rails']['jws_private_key'] ||= SecretsHelper.generate_rsa(4096).to_pem
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

    def parse_runtime_dir
      Gitlab['runtime_dir'] ||= '/run'

      run_dir = Gitlab['runtime_dir']
      if Gitlab['node']['filesystem2'].nil?
        Chef::Log.warn 'No filesystem2 variables in Ohai, disabling runtime_dir'
        Gitlab['runtime_dir'] = nil
      else
        fs = Gitlab['node']['filesystem2']['by_mountpoint'][run_dir]
        if fs.nil? || fs['fs_type'] != 'tmpfs'
          Chef::Log.warn "Runtime directory '#{run_dir}' is not a tmpfs."
          Gitlab['runtime_dir'] = nil
        end
      end
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

    def parse_repository_storage
      return if Gitlab['gitlab_rails']['repositories_storages']
      gitaly_address = Gitaly.gitaly_address

      Gitlab['gitlab_rails']['repositories_storages'] ||= {
        "default" => {
          "path" => "/var/opt/gitlab/git-data/repositories",
          "gitaly_address" => gitaly_address,
          "failure_count_threshold" => 10,
          "failure_wait_time" => 30,
          "failure_reset_time" => 1800,
          "storage_timeout" => 30
        }
      }
    end

    def parse_gitlab_trusted_proxies
      Gitlab['nginx']['real_ip_trusted_addresses'] ||= Gitlab['node']['gitlab']['nginx']['real_ip_trusted_addresses']
      Gitlab['gitlab_rails']['trusted_proxies'] ||= Gitlab['nginx']['real_ip_trusted_addresses']
    end

    def parse_rack_attack_protected_paths
      # Fixing common user's input mistakes for rake attack protected paths
      return unless Gitlab['gitlab_rails']['rack_attack_protected_paths']

      # append leading slash if missing
      Gitlab['gitlab_rails']['rack_attack_protected_paths'].map! do |path|
        path.start_with?('/') ? path : '/' + path
      end

      # append urls to the list but without relative_url
      if Gitlab['gitlab_rails']['gitlab_relative_url']
        paths_without_relative_url = []
        Gitlab['gitlab_rails']['rack_attack_protected_paths'].each do |path|
          if path.start_with?(Gitlab['gitlab_rails']['gitlab_relative_url'] + '/')
            stripped_path = path.sub(Gitlab['gitlab_rails']['gitlab_relative_url'], '')
            paths_without_relative_url.push(stripped_path)
          end
        end
        Gitlab['gitlab_rails']['rack_attack_protected_paths'].concat(paths_without_relative_url)
      end

    end

    def handle_legacy_variables
      Gitlab['gitlab_rails']['stuck_ci_jobs_worker_cron'] ||= Gitlab['gitlab_rails']['stuck_ci_builds_worker_cron']
      if Gitlab['gitlab_rails']['stuck_ci_builds_worker_cron']
        warning = ["Legacy config value gitlab_rails['stuck_ci_builds_worker_cron'] found; it is DEPRECATED",
                   "Please use gitlab_rails['stuck_ci_jobs_worker_cron'] from now on"]
        Chef::Log.warn(warning.join("\n"))
      end
    end

    def public_path
      "#{Gitlab['node']['package']['install-dir']}/embedded/service/gitlab-rails/public"
    end

    def parse_gitaly_variables
      parse_gitaly_storages
    end

    # This method cannot be inside of libraries/gitaly.rb for now
    # because storage gets parsed in libraries/gitlab_shell.rb
    # and libraries/gitlab_rails.rb
    def parse_gitaly_storages
      return unless Gitlab['gitaly']['storage'].nil?

      storages = []
      Gitlab['gitlab_rails']['repositories_storages'].each do |key, value|
        storages << {
                      'name' => key,
                      'path' => value['path']
                    }
      end
      Gitlab['gitaly']['storage'] = storages
    end
  end
end unless defined?(GitlabRails) # Prevent reloading during converge, so we can test
