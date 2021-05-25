require 'mixlib/shellout'
require_relative 'helper'
require_relative 'deprecations'

class OmnibusHelper
  include ShellOutHelper
  attr_reader :node

  def initialize(node)
    @node = node
  end

  def service_dir_enabled?(service_name)
    File.symlink?("/opt/gitlab/service/#{service_name}")
  end

  def should_notify?(service_name)
    service_dir_enabled?(service_name) && service_up?(service_name) && service_enabled?(service_name)
  end

  def not_listening?(service_name)
    return true unless service_enabled?(service_name)

    service_down?(service_name)
  end

  def service_enabled?(service_name)
    # As part of https://gitlab.com/gitlab-org/omnibus-gitlab/issues/2078 services are
    # being split to their own dedicated cookbooks, and attributes are being moved from
    # node['gitlab'][service_name] to node[service_name]. Until they've been moved, we
    # need to check both.
    return node['monitoring'][service_name]['enable'] if node['monitoring'].key?(service_name)
    return node['gitlab'][service_name]['enable'] if node['gitlab'].key?(service_name)

    node[service_name]['enable']
  end

  def service_up?(service_name)
    success?("/opt/gitlab/init/#{service_name} status")
  end

  def service_down?(service_name)
    failure?("/opt/gitlab/init/#{service_name} status")
  end

  def is_managed_and_offline?(service_name)
    service_enabled?(service_name) && service_down?(service_name)
  end

  def user_exists?(username)
    success?("id -u #{username}")
  end

  def group_exists?(group)
    success?("getent group #{group}")
  end

  def expected_user?(file, user)
    File.stat(file).uid == Etc.getpwnam(user).uid
  end

  def expected_group?(file, group)
    File.stat(file).gid == Etc.getgrnam(group).gid
  end

  def expected_owner?(file, user, group)
    expected_user?(file, user) && expected_group?(file, group)
  end

  # Checks whether a specific resource exist in runtime
  #
  # @example usage
  #   omnibus_helper.resource_available?('runit_service[postgresql]')
  #
  # @param [String] name of the resource
  # @return [Boolean]
  def resource_available?(name)
    node.run_context.resource_collection.find(name)

    true
  rescue Chef::Exceptions::ResourceNotFound
    false
  end

  def is_deprecated_praefect_config?
    return unless node['praefect']['storage_nodes'].is_a?(Array)

    msg = <<~EOS
      Specifying Praefect storage nodes as an array is deprecated. Support will be removed in a future release.
      Check the latest gitlab.rb.template for the current format.
      https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template
    EOS

    LoggingHelper.deprecation(msg)
  end

  def print_root_account_details
    return unless node['gitlab']['bootstrap']['enable']

    initial_password_provided = ENV['GITLAB_ROOT_PASSWORD'] || node['gitlab']['gitlab-rails']['initial_root_password']

    msg = if initial_password_provided
            "Default admin account has been configured with username `root` and the password you specified in `/etc/gitlab/gitlab.rb` file."
          else
            <<~EOS
              It seems you haven't specified an initial root password while configuring the GitLab instance.
              On your first visit to  your GitLab instance, you will be presented with a screen to set a
              password for the default admin account with username `root`.
            EOS
          end
    LoggingHelper.note(msg)
  end

  def check_invalid_pg_ha
    return unless Services.enabled?('repmgr') && Services.enabled?('repmgrd')

    geo_pg_helper = GeoPgHelper.new(node)
    pg_helper = PgHelper.new(node)

    main_db_version = pg_helper.database_version if Services.enabled?('postgresql')
    geo_db_version = geo_pg_helper.database_version if Services.enabled?('geo_postgresql')
    db_version = node['postgresql']['version'] || main_db_version || geo_db_version

    return unless db_version.nil? || db_version.to_f >= 12

    raise 'The included Repmgr is not supported on PostgreSQL 12, please use Patroni: https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html'
  end

  def self.utf8_variable?(var)
    ENV[var]&.downcase&.include?('utf-8') || ENV[var]&.downcase&.include?('utf8')
  end

  def self.valid_variable?(var)
    !ENV[var].nil? && !ENV[var].empty?
  end

  def self.on_exit
    LoggingHelper.report
  end

  def self.deprecated_os_list
    # This hash follows the format `'ohai-slug' => 'EOL version'
    # example: deprecated_os = { 'raspbian-8' => 'GitLab 11.8' }
    {
      'raspbian-9' => 'GitLab 13.4',
      'debian-8' => 'GitLab 13.4',
      'centos-6' => 'GitLab 13.7',
      'ubuntu-16.04' => 'GitLab 14.0',
      'opensuseleap-15.1' => 'GitLab 14.0'
    }
  end

  def self.is_deprecated_os?
    deprecated_os = deprecated_os_list
    ohai ||= Ohai::System.new.tap do |oh|
      oh.all_plugins(['platform'])
    end.data

    platform = ohai['platform']
    platform = 'raspbian' if ohai['platform'] == 'debian' && /armv/.match?(ohai['kernel']['machine'])

    os_string = "#{platform}-#{ohai['platform_version']}"

    # Find list of deprecated OS that may match the system OS. Like debian-7.11 matching debian-7
    matching_list = deprecated_os.keys.select { |x| os_string =~ Regexp.new(x) }

    return if matching_list.empty?

    message = <<~EOS
      Your OS, #{os_string}, will be deprecated soon.
      Starting with #{deprecated_os[matching_list.first]}, packages will not be built for it.
      Switch or upgrade to a supported OS, see https://docs.gitlab.com/omnibus/package-information/deprecated_os.html for more information.
    EOS

    LoggingHelper.deprecation(message)
  end

  def self.parse_current_version
    return unless File.exist?("/opt/gitlab/version-manifest.json")

    version_manifest = JSON.parse(File.read("/opt/gitlab/version-manifest.json"))
    version_components = version_manifest['build_version'].split(".")
    version_components[0, 2].join(".")
  end

  def self.check_deprecations
    current_version = parse_current_version
    return unless current_version

    # We need configuration from /etc/gitlab/gitlab.rb in a structure similar
    # to what will be stored in /opt/gitlab/nodes/{fqdn}.json. This means
    # config keys should have `gitlab` as their parent key (for example,
    # nginx['listen_address'] should become `gitlab['nginx']['listen_address']`
    # We are doing something similar in check_config command.
    gitlab_rb_config = Gitlab['node'].normal

    removal_messages = Gitlab::Deprecations.check_config(current_version, gitlab_rb_config, :removal)
    removal_messages.each do |msg|
      LoggingHelper.removal(msg)
    end
    raise "Removed configurations found in gitlab.rb. Aborting reconfigure." unless removal_messages.empty?

    deprecation_messages = Gitlab::Deprecations.check_config(current_version, gitlab_rb_config, :deprecation)
    deprecation_messages.each do |msg|
      LoggingHelper.deprecation(msg)
    end
  end

  def self.check_environment
    ENV['LD_LIBRARY_PATH'] && LoggingHelper.warning('LD_LIBRARY_PATH was found in the env variables, this may cause issues with linking against the included libraries.')
  end

  def self.check_locale
    error_message = "Environment variable %{variable} specifies a non-UTF-8 locale. GitLab requires UTF-8 encoding to function properly. Please check your locale settings."
    relevant_vars = %w[LC_CTYPE LC_COLLATE]

    # LC_ALL variable trumps everything. If it specify a locale, we  can make
    # a decision based on that and need not check more.
    if valid_variable?('LC_ALL')
      LoggingHelper.warning(format(error_message, variable: 'LC_ALL')) unless utf8_variable?('LC_ALL')
      return
    end

    # We know LC_COLLATE and LC_CTYPE variables being non-UTF8 will definitely
    # break stuff. So we check for them.
    individually_set_vars = relevant_vars.select { |var| valid_variable?(var) }
    individually_set_vars.each do |var|
      LoggingHelper.warning(format(error_message, variable: var)) unless utf8_variable?(var)
    end

    # If both LC_COLLATE and LC_CTYPE are UTF-8, initdb won't break. However,
    # if one of them is set and the other is empty, we defer to LANG.
    return if individually_set_vars == relevant_vars

    # Instead of setting LC_COLLATE and LC_CTYPE individually, users may have
    # also just set LANG variable. Next, we check for that. For example where
    # LC_CTYPE is UTF-8, but LANG is not (and thus LC_COLLATE is not).
    # This scenario can break initdb.
    return unless valid_variable?('LANG')

    LoggingHelper.warning(format(error_message, variable: 'LANG')) unless utf8_variable?('LANG')
  end

  def restart_service_resource(service)
    return "sidekiq_service[#{service}]" if %w(sidekiq).include?(service)
    return "unicorn_service[#{service}]" if %w(unicorn).include?(service)

    "runit_service[#{service}]"
  end
end
