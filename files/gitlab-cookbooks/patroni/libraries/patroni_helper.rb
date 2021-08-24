class PatroniHelper < BaseHelper
  include ShellOutHelper

  DCS_ATTRIBUTES ||= %w(loop_wait ttl retry_timeout maximum_lag_on_failover max_timelines_history master_start_timeout).freeze
  DCS_POSTGRESQL_ATTRIBUTES ||= %w(use_pg_rewind use_slots).freeze

  attr_reader :node

  def ctl_command
    "#{node['package']['install-dir']}/embedded/bin/patronictl"
  end

  def service_name
    'patroni'
  end

  def running?
    OmnibusHelper.new(node).service_up?(service_name)
  end

  def bootstrapped?
    File.exist?(File.join(node['postgresql']['dir'], 'data', 'patroni.dynamic.json'))
  end

  def scope
    node['patroni']['scope']
  end

  def node_status
    return 'not running' unless running?

    cmd = "#{ctl_command} -c #{node['patroni']['dir']}/patroni.yaml list | grep #{node.name} | cut -d '|' -f 5"
    do_shell_out(cmd).stdout.chomp.strip
  end

  def use_tls?
    !!(node['patroni']['tls_certificate_file'] && node['patroni']['tls_key_file'])
  end

  def verify_client?
    !!(node['patroni']['tls_client_mode'] && node['patroni']['tls_client_mode'] != 'none')
  end

  def dynamic_settings(pg_helper)
    dcs = {
      'postgresql' => {
        'parameters' => {}
      },
      'slots' => {}
    }

    DCS_ATTRIBUTES.each do |key|
      dcs[key] = node['patroni'][key]
    end

    DCS_POSTGRESQL_ATTRIBUTES.each do |key|
      dcs['postgresql'][key] = node['patroni'][key]
    end

    node['patroni']['postgresql'].each do |key, value|
      dcs['postgresql']['parameters'][key] = value
    end

    # work around to support PG12 and PG13 concurrently
    if (pg_helper.database_version || pg_helper.version).major.to_i >= 13
      dcs['postgresql']['parameters'].delete('wal_keep_segments')
    else
      dcs['postgresql']['parameters'].delete('wal_keep_size')
    end

    node['patroni']['replication_slots'].each do |slot_name, options|
      dcs['slots'][slot_name] = parse_replication_slots_options(options)
    end

    if node['patroni']['standby_cluster']['enable']
      dcs['standby_cluster'] = {}

      node['patroni']['standby_cluster'].each do |key, value|
        next if key == 'enable'

        dcs['standby_cluster'][key] = value
      end
    end

    dcs
  end

  def public_attributes
    return {} unless node['patroni']['enable']

    attributes = {
      'config_dir' => node['patroni']['dir'],
      'data_dir' => File.join(node['patroni']['dir'], 'data'),
      'log_dir' => node['patroni']['log_directory'],
      'api_address' => "#{use_tls? ? 'https' : 'http'}://#{node['patroni']['connect_address'] || '127.0.0.1'}:#{node['patroni']['port']}"
    }
    attributes.merge!(
      'tls_verify' => node['patroni']['tls_verify'],
      'ca_file' => node['patroni']['tls_ca_file'],
      'verify_client' => verify_client?,
      'client_cert' => node['patroni']['tls_client_certificate_file'],
      'client_key' => node['patroni']['tls_client_key_file']
    ) if use_tls?

    {
      'patroni' => attributes.compact
    }
  end

  private

  # Parse replication slots attributes
  #
  # We currently support only physical replication
  def parse_replication_slots_options(options)
    return unless options['type'] == 'physical'

    {
      'type' => 'physical'
    }
  end
end
