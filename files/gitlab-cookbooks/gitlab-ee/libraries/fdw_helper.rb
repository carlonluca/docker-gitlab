class FdwHelper
  FOREIGN_SCHEMA = 'gitlab_secondary'.freeze
  DEFAULT_SCHEMA = 'public'.freeze

  attr_reader :node

  def initialize(node)
    @node = node
  end

  def fdw_enabled?
    node['gitlab']['geo-secondary']['db_fdw']
  end

  def fdw_dbname
    node['gitlab']['gitlab-rails']['db_database']
  end

  def fdw_user
    node['gitlab']['geo-postgresql']['fdw_external_user']
  end

  def fdw_password
    node['gitlab']['geo-postgresql']['fdw_external_password']
  end

  def fdw_host
    node['gitlab']['gitlab-rails']['db_host']
  end

  def fdw_port
    node['gitlab']['gitlab-rails']['db_port']
  end

  def pg_hba_entries
    entries = []
    node['postgresql']['md5_auth_cidr_addresses'].each do |cidr|
      entries.push({
                     type: 'host',
                     database: fdw_dbname,
                     user: fdw_user,
                     cidr: cidr,
                     method: 'md5'
                   })
    end
    entries
  end
end unless defined?(FdwHelper) # Prevent reloading in chefspec: https://github.com/sethvargo/chefspec/issues/562#issuecomment-74120922
