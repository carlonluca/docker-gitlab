require 'timeout'

class ConsulHelper
  attr_reader :node, :default_configuration, :default_server_configuration

  # List of existing services that we provide configuration for consul monitoring
  #
  # When adding a new service to consul, add to the constant below and make sure you
  # provide an `enable_service_#{service_name}` and `disable_service_#{service_name}` recipe
  SERVICES = %w(postgresql).freeze

  def initialize(node)
    @node = node
    @default_configuration = {
      'client_addr' => nil,
      'datacenter' => 'gitlab_consul',
      'disable_update_check' => true,
      'enable_script_checks' => true,
      'node_name' => node['consul']['node_name'] || node['fqdn'],
      'rejoin_after_leave' => true,
      'server' => false
    }
    @default_server_configuration = {
      'bootstrap_expect' => 3
    }
  end

  def watcher_config(watcher)
    {
      watches: [
        {
          type: 'service',
          service: watcher,
          args: ["#{node['consul']['script_directory']}/#{watcher_handler(watcher)}"]
        }
      ]
    }
  end

  def watcher_handler(watcher)
    node['consul']['watcher_config'][watcher]['handler']
  end

  def configuration
    config = Chef::Mixin::DeepMerge.merge(
      default_configuration,
      node['consul']['configuration']
    ).select { |k, v| !v.nil? }
    if config['server']
      return Chef::Mixin::DeepMerge.merge(
        default_server_configuration, config
      ).to_json
    end
    config.to_json
  end

  def api_url
    %w[https http].each do |scheme|
      port = api_port(scheme)

      # Positive value means enabled API port(https://www.consul.io/docs/agent/options#ports)
      return "#{scheme}://#{api_address(scheme)}:#{port}" if port.positive?
    end
  end

  def api_port(scheme)
    default_port = { 'http' => 8500, 'https' => -1 }

    node.dig('consul', 'configuration', 'ports', scheme) || default_port[scheme]
  end

  def api_address(scheme)
    default_address = 'localhost'
    config_address = node.dig('consul', 'configuration', 'addresses', scheme) || node.dig('consul', 'configuration', 'client_addr')

    config_address.nil? || IPAddr.new(config_address).to_i.zero? ? default_address : config_address
  rescue IPAddr::InvalidAddressError
    # Have a best try when config address is invalid IP, such as a list of addresses
    default_address
  end

  def postgresql_service_config
    return node['consul']['service_config']['postgresql'] || {} unless node['consul']['service_config'].nil?

    ha_solution = postgresql_ha_solution

    {
      'service' => {
        'name' => node['consul']['internal']['postgresql_service_name'],
        'address' => '',
        'port' => node['postgresql']['port'],
        'check' => {
          'id': "service:#{node['consul']['internal']['postgresql_service_name']}",
          'interval' => node['consul']['internal']['postgresql_service_check_interval'],
          'status': node['consul']['internal']['postgresql_service_check_status'],
          'args': node['consul']['internal']["postgresql_service_check_args_#{ha_solution}"]
        }
      }
    }
  end

  def postgresql_ha_solution
    return 'patroni_standby_cluster' if node['patroni'].key?('standby_cluster') && node['patroni']['standby_cluster']['enable']

    'patroni'
  end

  # Return a list of enabled services
  #
  # @return [Array] list of enabled services
  def enabled_services
    node['consul']['services']
  end

  # Return a list of disabled services
  #
  # The list is generated by intersecting the existing services with the list of enabled
  #
  # @return [Array] list of services that are disabled
  def disabled_services
    SERVICES - node['consul']['services']
  end

  def installed_version
    return unless OmnibusHelper.new(@node).service_up?('consul')

    command = '/opt/gitlab/embedded/bin/consul version'
    command_output = VersionHelper.version(command)
    raise "Execution of the command `#{command}` failed" unless command_output

    version_match = command_output.match(/Consul v(?<consul_version>\d*\.\d*\.\d*)/)
    raise "Execution of the command `#{command}` generated unexpected output `#{command_output.strip}`" unless version_match

    version_match['consul_version']
  end

  def running_version
    return unless OmnibusHelper.new(@node).service_up?('consul')

    info = get_api('/v1/agent/self') do |response|
      response.code == '200' ? JSON.parse(response.body, symbolize_names: true) : {}
    end

    info[:Config][:Version] unless info.empty?
  end

  private

  def get_api(endpoint, header = nil)
    uri = URI(api_url)

    Timeout.timeout(30, Timeout::Error, "Timed out waiting for Consul to start") do
      loop do
        Net::HTTP.start(uri.host, uri.port) do |http|
          http.request_get(endpoint, header) do |response|
            return yield response
          end
        end
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        sleep 1
        next
      else
        break
      end
    end
  end
end
