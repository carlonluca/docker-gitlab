require 'json'

module WatchHelper
  WATCHER_FILENAME_PREFIX = 'watcher_'.freeze

  class Watcher
    attr_reader :name, :handler_script, :handler_template, :type, :consul_config_file, :template_variables, :service_name

    def initialize(name = nil, handler_script = nil, handler_template = nil, type = nil, consul_watch_config_directory = nil, template_variables = {})
      @name = name
      @handler_script = handler_script
      @handler_template = handler_template
      @type = type
      @consul_config_file = "#{consul_watch_config_directory}/#{WATCHER_FILENAME_PREFIX}#{name}.json"
      @service_name = "service:#{name}"
      @template_variables = template_variables.merge({ "watcher_service_name" => @service_name })
    end

    def consul_config
      {
        watches: [
          {
            type: @type,
            service: @name,
            args: [handler_script]
          }
        ]
      }.to_json
    end
  end

  class WatcherConfig
    attr_reader :node, :enabled_watchers, :standard_watchers

    def initialize(node)
      @node = node

      # user configuration
      @enabled_watchers = @node['consul']['watchers']
      @handler_directory = @node['consul']['script_directory']
      @consul_config_directory = @node['consul']['config_dir']

      # library standards
      @standard_watchers = [
        Watcher.new(name = node['consul']['internal']['postgresql_service_name'],
                    handler_script = "#{@handler_directory}/failover_postgresql_in_pgbouncer",
                    handler_template = 'failover_pgbouncer.erb',
                    type = 'service',
                    consul_config = @consul_config_directory,
                    template_variables = node['consul'].to_hash.merge({ 'database_name' => node['gitlab']['gitlab-rails']['db_database'] })
                   )
      ]

      # Backward compatibility if someone had actually made a customer
      # watcher, even though it was never documented or supported
      @user_watcher_configs = @node['consul']['watcher_config'] || {}

      @user_watchers = []
      @user_watcher_configs.each do |watcher, config|
        handler = config['handler']
        @user_watchers.push(Watcher.new(name = watcher,
                                        handler_script = "#{@handler_directory}/#{handler}",
                                        handler_template = "#{handler}.erb",
                                        type = 'service',
                                        consul_config = @consul_config_directory,
                                        template_variables = node['consul'].to_hash
                                       )
                           )
      end

      @all_watchers = @standard_watchers + @user_watchers
    end

    def watchers
      @all_watchers.select { |watcher| @enabled_watchers.include? watcher.name }
    end

    def excess_watcher_configs
      enabled_watcher_configs = watchers.map { |w| File.basename w.consul_config_file }
      Dir.glob("#{@consul_config_directory}/*")
        .reject { |f| !File.basename(f).start_with? WATCHER_FILENAME_PREFIX }
        .reject { |f| enabled_watcher_configs.include? f }
    end

    def excess_handler_scripts
      enabled_handlers = watchers.map { |w| File.basename w.handler_script }
      Dir.glob("#{@handler_directory}/*")
        .reject { |h| enabled_handlers.include? h }
    end
  end
end
