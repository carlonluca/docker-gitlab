#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# Copyright:: Copyright (c) 2014 GitLab.com
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

require 'mixlib/shellout'
require 'uri'
require 'digest'

module ShellOutHelper

  def do_shell_out(cmd, user = nil, cwd = nil)
    o = Mixlib::ShellOut.new(cmd, user: user, cwd: cwd)
    o.run_command
    o
  rescue Errno::EACCES
    Chef::Log.info("Cannot execute #{cmd}.")
    o
  rescue Errno::ENOENT
    Chef::Log.info("#{cmd} does not exist.")
    o
  end

  def success?(cmd)
    o = do_shell_out(cmd)
    o.exitstatus == 0
  end

  def failure?(cmd)
    o = do_shell_out(cmd)
    o.exitstatus != 0
  end
end

class PgHelper
  include ShellOutHelper
  attr_reader :node

  def initialize(node)
    @node = node
  end

  def is_running?
    OmnibusHelper.service_up?("postgresql")
  end

  def database_exists?(db_name)
    psql_cmd(["-d 'template1'",
              "-c 'select datname from pg_database' -A",
              "| grep -x #{db_name}"])
  end

  def user_exists?(db_user)
    psql_cmd(["-d 'template1'",
              "-c 'select usename from pg_user' -A",
              "|grep -x #{db_user}"])
  end

  def is_slave?
    psql_cmd(["-d 'template1'",
              "-c 'select pg_is_in_recovery()' -A",
              "|grep -x t"])
  end

  def psql_cmd(cmd_list)
    cmd = ["/opt/gitlab/bin/gitlab-psql", cmd_list.join(" ")].join(" ")
    success?(cmd)
  end
end

class OmnibusHelper
  extend ShellOutHelper

  def self.should_notify?(service_name)
    File.symlink?("/opt/gitlab/service/#{service_name}") && service_up?(service_name)
  end

  def self.not_listening?(service_name)
    File.exists?("/opt/gitlab/service/#{service_name}/down") && service_down?(service_name)
  end

  def self.service_up?(service_name)
    success?("/opt/gitlab/embedded/bin/sv status #{service_name}")
  end

  def self.service_down?(service_name)
    failure?("/opt/gitlab/embedded/bin/sv status #{service_name}")
  end

  def self.user_exists?(username)
    success?("id -u #{username}")
  end
end

module AuthorizeHelper

  def query_gitlab_rails(uri, name)
    warn("Connecting to GitLab to generate new app_id and app_secret for #{name}.")
    runner_cmd = create_or_find_authorization(uri, name)
    cmd = execute_rails_runner(runner_cmd)
    do_shell_out(cmd)
  end

  def create_or_find_authorization(uri, name)
    args = %Q(redirect_uri: "#{uri}", name: "#{name}")

    app = %Q(app = Doorkeeper::Application.where(#{args}).first_or_create;)

    output = %Q(puts app.uid.concat(" ").concat(app.secret);)

    %W(
      #{app}
      #{output}
    ).join
  end

  def execute_rails_runner(cmd)
    %W(
      /opt/gitlab/bin/gitlab-rails
      runner
      -e production
      '#{cmd}'
    ).join(" ")
  end

  def warn(msg)
    Chef::Log.warn(msg)
  end

  def info(msg)
    Chef::Log.info(msg)
  end
end

class CiHelper
  extend ShellOutHelper
  extend AuthorizeHelper

  def self.authorize_with_gitlab(gitlab_external_url)
    redirect_uri = "#{Gitlab['ci_external_url']}/user_sessions/callback"
    app_name = "GitLab CI"

    o = query_gitlab_rails(redirect_uri, app_name)

    app_id, app_secret = nil
    if o.exitstatus == 0
      app_id, app_secret = o.stdout.chomp.split(" ")

      Gitlab['gitlab_ci']['gitlab_server'] = { 'url' => gitlab_external_url,
                                                 'app_id' => app_id,
                                                 'app_secret' => app_secret
                                               }

      SecretsHelper.write_to_gitlab_secrets
      info("Updated the gitlab-secrets.json file.")
    else
      warn("Something went wrong while trying to update gitlab-secrets.json. Check the file permissions and try reconfiguring again.")
    end

    { 'url' => gitlab_external_url, 'app_id' => app_id, 'app_secret' => app_secret }
  end

  def self.gitlab_server
    return unless Gitlab['gitlab_ci']['gitlab_server']
    Gitlab['gitlab_ci']['gitlab_server']
  end

  def self.gitlab_server_fqdn
    if gitlab_server && gitlab_server['url']
      uri = URI(gitlab_server['url'].to_s)
      uri.host
    else
      Gitlab['gitlab_rails']['gitlab_host']
    end
  end
end

class MattermostHelper
  extend ShellOutHelper
  extend AuthorizeHelper

  def self.authorize_with_gitlab(gitlab_external_url)
    redirect_uri = "#{Gitlab['mattermost_external_url']}/signup/gitlab/complete\r\n#{Gitlab['mattermost_external_url']}/login/gitlab/complete"
    app_name = "GitLab Mattermost"

    o = query_gitlab_rails(redirect_uri, app_name)

    app_id, app_secret = nil
    if o.exitstatus == 0
      app_id, app_secret = o.stdout.chomp.split(" ")
      gitlab_url = gitlab_external_url.chomp("/")

      Gitlab['mattermost']['gitlab_enable'] = true
      Gitlab['mattermost']['gitlab_secret'] = app_secret
      Gitlab['mattermost']['gitlab_id'] = app_id
      Gitlab['mattermost']['gitlab_scope'] = ""
      Gitlab['mattermost']['gitlab_auth_endpoint'] = "#{gitlab_url}/oauth/authorize"
      Gitlab['mattermost']['gitlab_token_endpoint'] = "#{gitlab_url}/oauth/token"
      Gitlab['mattermost']['gitlab_user_api_endpoint'] = "#{gitlab_url}/api/v3/user"

      SecretsHelper.write_to_gitlab_secrets
      info("Updated the gitlab-secrets.json file.")
    else
      warn("Something went wrong while trying to update gitlab-secrets.json. Check the file permissions and try reconfiguring again.")
    end
  end
end

class SecretsHelper

  def self.read_gitlab_secrets
    existing_secrets ||= Hash.new

    if File.exists?("/etc/gitlab/gitlab-secrets.json")
      existing_secrets = Chef::JSONCompat.from_json(File.read("/etc/gitlab/gitlab-secrets.json"))
    end

    existing_secrets.each do |k, v|
      if Gitlab[k]
        v.each do |pk, p|
          # Note: Specifiying a secret in gitlab.rb will take precendence over "gitlab-secrets.json"
          Gitlab[k][pk] ||= p
        end
      else
        warn("Ignoring section #{k} in /etc/gitlab/giltab-secrets.json, does not exist in gitlab.rb")
      end
    end
  end

  def self.write_to_gitlab_secrets
    secret_tokens = {
                      'gitlab_shell' => {
                        'secret_token' => Gitlab['gitlab_shell']['secret_token'],
                      },
                      'gitlab_rails' => {
                        'secret_key_base' => Gitlab['gitlab_rails']['secret_key_base'],
                        'db_key_base' => Gitlab['gitlab_rails']['db_key_base'],
                        'otp_key_base' => Gitlab['gitlab_rails']['otp_key_base']
                      },
                      'registry' => {
                        'http_secret' => Gitlab['registry']['http_secret'],
                        'internal_certificate' => Gitlab['registry']['internal_certificate'],
                        'internal_key' => Gitlab['registry']['internal_key']

                      },
                      'mattermost' => {
                        'email_invite_salt' => Gitlab['mattermost']['email_invite_salt'],
                        'file_public_link_salt' => Gitlab['mattermost']['file_public_link_salt'],
                        'email_password_reset_salt' => Gitlab['mattermost']['email_password_reset_salt'],
                        'sql_at_rest_encrypt_key' => Gitlab['mattermost']['sql_at_rest_encrypt_key']
                      }
                    }

    if Gitlab['gitlab_ci']['gitlab_server']
      warning = [
        "Legacy config value gitlab_ci['gitlab_server'] found; value will be REMOVED. For reference, it was:",
        Gitlab['gitlab_ci']['gitlab_server'].to_json
      ]

      warn(warning.join("\n\n"))
    end

    if Gitlab['mattermost']['gitlab_enable']
      gitlab_oauth = {
                        'gitlab_enable' => Gitlab['mattermost']['gitlab_enable'],
                        'gitlab_secret' => Gitlab['mattermost']['gitlab_secret'],
                        'gitlab_id' => Gitlab['mattermost']['gitlab_id'],
                        'gitlab_scope' => Gitlab['mattermost']['gitlab_scope'],
                        'gitlab_auth_endpoint' => Gitlab['mattermost']['gitlab_auth_endpoint'],
                        'gitlab_token_endpoint' => Gitlab['mattermost']['gitlab_token_endpoint'],
                        'gitlab_user_api_endpoint' => Gitlab['mattermost']['gitlab_user_api_endpoint']
                     }
      secret_tokens['mattermost'].merge!(gitlab_oauth)
    end

    if File.directory?("/etc/gitlab")
      File.open("/etc/gitlab/gitlab-secrets.json", "w") do |f|
        f.puts(
          Chef::JSONCompat.to_json_pretty(secret_tokens)
        )
        system("chmod 0600 /etc/gitlab/gitlab-secrets.json")
      end
    end
  end
end

module SingleQuoteHelper

  def single_quote(string)
   "'#{string}'" unless string.nil?
  end

end

class RedhatHelper

  def self.system_is_rhel7?
    platform_family == "rhel" && platform_version =~ /7\./
  end

  def self.platform_family
    case platform
    when /oracle/, /centos/, /redhat/, /scientific/, /enterpriseenterprise/, /amazon/, /xenserver/, /cloudlinux/, /ibm_powerkvm/, /parallels/
      "rhel"
    else
      "not redhat"
    end
  end

  def self.platform
    contents = read_release_file
    get_redhatish_platform(contents)
  end

  def self.platform_version
    contents = read_release_file
    get_redhatish_version(contents)
  end

  def self.read_release_file
    if File.exists?("/etc/redhat-release")
      contents = File.read("/etc/redhat-release").chomp
    else
      "not redhat"
    end
  end

  # Taken from Ohai
  # https://github.com/chef/ohai/blob/31f6415c853f3070b0399ac2eb09094eb81939d2/lib/ohai/plugins/linux/platform.rb#L23
  def self.get_redhatish_platform(contents)
    contents[/^Red Hat/i] ? "redhat" : contents[/(\w+)/i, 1].downcase
  end

  # Taken from Ohai
  # https://github.com/chef/ohai/blob/31f6415c853f3070b0399ac2eb09094eb81939d2/lib/ohai/plugins/linux/platform.rb#L27
  def self.get_redhatish_version(contents)
    contents[/Rawhide/i] ? contents[/((\d+) \(Rawhide\))/i, 1].downcase : contents[/release ([\d\.]+)/, 1]
  end
end

class VersionHelper
  extend ShellOutHelper

  def self.version(cmd)
    result = do_shell_out(cmd)
    if result.exitstatus == 0
      result.stdout
    else
      nil
    end
  end
end

class MattermostHelper
  extend ShellOutHelper

  def initialize(node, mattermost_user, mattermost_home)
    @node = node
    @mattermost_user = mattermost_user
    @mattermost_home = mattermost_home
    @config_file_path = File.join(@mattermost_home, 'config.json')
    @status = {}
  end

  def version
    return @status[:version] if @status.key?(:version)

    cmd = self.class.version_cmd(@config_file_path)
    result = self.class.do_shell_out(cmd, @mattermost_user, "/opt/gitlab/embedded/service/mattermost")

    if result.exitstatus == 0
      @status[:version] = result.stdout
    else
      @status[:version] = nil
    end
  end

  def self.version_cmd(path)
    "/opt/gitlab/embedded/bin/mattermost -config='#{path}' -version"
  end

  def self.upgrade_db_30(path, user, team_name)
    cmd = upgrade_db_30_cmd(path, team_name)
    result = do_shell_out(cmd, user, "/opt/gitlab/embedded/service/mattermost")
    result.exitstatus
  end

  def self.upgrade_db_30_cmd(path, team_name)
    "/opt/gitlab/embedded/bin/mattermost -config='#{path}' -upgrade_db_30 -confirm_backup='YES' -team_name='#{team_name}'"
  end
end

class CertificateHelper
  include ShellOutHelper

  def initialize(trusted_cert_dir, omnibus_cert_dir, user_dir)
    @trusted_certs_dir = trusted_cert_dir
    @omnibus_certs_dir = omnibus_cert_dir
    @directory_hash_file = File.join(user_dir, "trusted-certs-directory-hash")
  end

  def whitelisted_files
    [
      File.join(@omnibus_certs_dir, "README"),
      File.join(@omnibus_certs_dir, "cacert.pem")
    ]
  end

  def is_x509_certificate?(file)
    return false unless valid?(file)

    begin
      OpenSSL::X509::Certificate.new(File.read(file)) # DER- or PEM-encoded
      true
    rescue OpenSSL::X509::CertificateError => e
      warn("ERROR: " + file + ": OpenSSL error: " + e.message + "!")
      false
    rescue Exception => e
      warn(e.message)
      false
    end
  end

  # If the number of files between the two directories is different
  # something got added so trigger the run
  def new_certificate_added?
    return true unless File.exists?(@directory_hash_file)

    stored_hash = File.read(@directory_hash_file)
    trusted_certs_dir_hash != stored_hash
  end

  def trusted_certs_dir_hash
    files = Dir[File.join(@trusted_certs_dir, "*")]
    files_modification_time = files.map { |name| File.stat(name).mtime if valid?(name) }
    Digest::SHA1.hexdigest(files_modification_time.join)
  end

  # Get all files in /opt/gitlab/embedded/ssl/certs
  # - "cacert.pem", "README" -> ignore
  # - if valid certificate
  #   - if symlink
  #     - remove broken symlinks
  #     - ignore if pointing to /etc/gitlab/trusted-certs
  #     - ignore because it might be a symlink user created
  #   - else
  #     - copy to trusted-certs dir
  # - else (not valid)
  #   raise and error
  def move_existing_certificates
    Dir.glob(File.join(@omnibus_certs_dir, "*")) do |file|
      case
      when !valid?(file),whitelisted?(file)
        next
      when is_x509_certificate?(file)
        move_certificate(file)
      else
        raise_msg(file)
      end
    end
  end

  def whitelisted?(file)
    whitelisted_files.include?(file) || whitelisted_files.include?(File.realpath(file))
  end

  def valid?(file)
    exists = File.exists?(file)
    FileUtils.rm_f(file) if File.symlink?(file) && !exists

    exists
  end

  def move_certificate(file)
    return if File.symlink?(file) && File.readlink(file).start_with?(@trusted_certs_dir)

    # Move the certs to the trusted certs directory if it is located within our managed certs directory
    # Otherwise copy the cert to the trusted certs directory
    realpath = File.realpath(file)
    if realpath.start_with?(@omnibus_certs_dir)
      FileUtils.mv(realpath, @trusted_certs_dir, force: true)
    else
      FileUtils.cp(realpath, @trusted_certs_dir)
    end

    FileUtils.rm_f(file) if File.symlink?(file)
    puts "\n Moving #{realpath}"
  end

  def link_certificates
    c_rehash
    link_to_omnibus_ssl_directory
    log_directory_hash
  end

  # c_rehash ran so we now have valid hashed names
  # Skip all files that are not symlinks
  # If they are symlinks, make sure they are valid certificates
  def link_to_omnibus_ssl_directory
    Dir.glob(File.join(@trusted_certs_dir, "*")) do |trusted_cert|
      if File.symlink?(trusted_cert) && is_x509_certificate?(trusted_cert)
        hash_name = File.basename(trusted_cert)
        certificate_path = File.realpath(trusted_cert)
        symlink_path = File.join(@omnibus_certs_dir, hash_name)

        FileUtils.ln_s certificate_path, symlink_path unless File.exist?(symlink_path)
      else
        puts "\n Skipping #{trusted_cert}."
      end
    end
  end

  def c_rehash
    cmd = "/opt/gitlab/embedded/bin/c_rehash #{@trusted_certs_dir}"
    result = do_shell_out(cmd)
    result.exitstatus
  end

  def log_directory_hash
    File.write(@directory_hash_file, trusted_certs_dir_hash)
  end

  def raise_msg(file)
    raise "ERROR: Not a certificate: #{file} -> #{File.realpath(file)}"
  end
end
