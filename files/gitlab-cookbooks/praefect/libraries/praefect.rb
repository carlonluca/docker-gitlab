module Praefect
  class << self
    def parse_variables
      inform_election_strategy
      parse_virtual_storages
    end

    def inform_election_strategy
      return unless Gitlab['praefect']['enable']

      return unless Gitlab['praefect']['failover_election_strategy']

      LoggingHelper.note("From GitLab 14.0 onwards, `per_repository` is the only supported failover election strategy for Praefect. Hence the setting `praefect['failover_election_strategy']` will be ignored and can be safely removed from `/etc/gitlab/gitlab.rb`.")
    end

    # parse_virtual_storages converts the virtual storage's config object in to a format that better represents
    # the structure of Praefect's virtual storage configuration. Historically, virtual storages were configured
    # in omnibus as a hash of virtual storage names to nodes by name. parse_virtual_storages retains backwards
    # compatibility with this by moving unknown keys in a virtual storage's config under the 'nodes' key.
    def parse_virtual_storages
      return if Gitlab['praefect']['virtual_storages'].nil?

      raise "Praefect virtual_storages must be a hash" unless Gitlab['praefect']['virtual_storages'].is_a?(Hash)

      # These are the known keys of virtual storage's configuration. Values under
      # these keys are placed in to the root of the virtual storage's configuration. Unknown
      # keys are assumed to be nodes of the virtual storage and are moved under the 'nodes'
      # key.
      known_keys = ['default_replication_factor']
      deprecation_logged = false

      virtual_storages = {}
      Gitlab['praefect']['virtual_storages'].map do |virtual_storage, config_keys|
        raise "nodes of a Praefect virtual_storage must be a hash" unless config_keys.is_a?(Hash)

        config = { 'nodes' => config_keys['nodes'] || {} }
        config_keys.map do |key, value|
          next if key == 'nodes'

          if known_keys.include? key
            config[key] = value
            next
          end

          unless deprecation_logged
            LoggingHelper.deprecation(
              <<~EOS
                Configuring the Gitaly nodes directly in the virtual storage's root configuration object has
                been deprecated in GitLab 13.12 and will no longer be supported in GitLab 15.0. Move the Gitaly
                nodes under the 'nodes' key as described in step 6 of https://docs.gitlab.com/ee/administration/gitaly/praefect.html#praefect.
              EOS
            )
            deprecation_logged = true
          end

          raise "Virtual storage '#{virtual_storage}' contains duplicate configuration for node '#{key}'" if config['nodes'][key]

          config['nodes'][key] = value
        end

        virtual_storages[virtual_storage] = config
      end

      Gitlab['praefect']['virtual_storages'] = virtual_storages
    end
  end
end
