module GeoSecondary
  GEO_DB_MIGRATIONS_PATH = 'ee/db/geo/migrate'.freeze
  GEO_SCHEMA_MIGRATIONS_PATH = 'ee/db/geo/schema_migrations'.freeze

  class << self
    def parse_variables
      parse_database
    end

    def node
      Gitlab[:node]
    end

    private

    def parse_database
      # If user hasn't specified a geo database, for now, we will use the
      # geo_secondary[`db_*`] keys to populate one. In the future, we can
      # deprecate geo_secondary[`db_*`] keys and ask users to  explicitly
      # set `gitlab_rails['databases']['geo']['db_*']` settings instead.
      Gitlab['gitlab_rails']['databases'] ||= {}
      Gitlab['gitlab_rails']['databases']['geo'] ||= { 'enable' => true }

      if geo_secondary_enabled? && geo_database_enabled?
        # Set default value for attributes of geo database based on
        # geo_secondary[`db_*`] settings.
        geo_database_attributes.each do |attribute|
          Gitlab['gitlab_rails']['databases']['geo'][attribute] ||= Gitlab['geo_secondary'][attribute] || node['gitlab']['geo-secondary'][attribute]
        end

        # Set db_migrations_path since Geo migration lives in a non-default place
        Gitlab['gitlab_rails']['databases']['geo']['db_migrations_paths'] = GEO_DB_MIGRATIONS_PATH
        Gitlab['gitlab_rails']['databases']['geo']['db_schema_migrations_path'] = GEO_SCHEMA_MIGRATIONS_PATH
      else
        # Weed out the geo database settings if both Geo and database is not enabled
        Gitlab['gitlab_rails']['databases'].delete('geo')
      end
    end

    def geo_secondary_enabled?
      Gitlab['geo_secondary_role']['enable'] || Gitlab['geo_secondary']['enable']
    end

    def geo_database_attributes
      node['gitlab']['geo-secondary'].to_h.keys.select { |k| k.start_with?('db_') }
    end

    def geo_database_enabled?
      Gitlab['gitlab_rails']['databases']['geo']['enable'] == true
    end
  end
end
