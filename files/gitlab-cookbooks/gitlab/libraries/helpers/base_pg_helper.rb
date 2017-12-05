# This is a base class to be inherited by PG Helpers
class BasePgHelper
  include ShellOutHelper
  attr_reader :node

  def initialize(node)
    @node = node
  end

  def is_running?
    OmnibusHelper.new(node).service_up?(service_name)
  end

  def database_exists?(db_name)
    psql_cmd(["-d 'template1'",
      "-c 'select datname from pg_database' -A",
      "| grep -x #{db_name}"])
  end

  def extension_exists?(extension_name)
    psql_cmd(["-d 'template1'",
      "-c 'select name from pg_available_extensions' -A",
      "| grep -x #{extension_name}"])
  end

  def extension_enabled?(extension_name, db_name)
    psql_cmd(["-d '#{db_name}'",
      "-c 'select extname from pg_extension' -A",
      "| grep -x #{extension_name}"])
  end

  def user_exists?(db_user)
    psql_cmd(["-d 'template1'",
      "-c 'select usename from pg_user' -A",
      "|grep -x #{db_user}"])
  end

  def user_options(db_user)
    db_user_safe = db_user.scan(/[a-z_][a-z0-9_-]*[$]?/).first
    query = "SELECT usecreatedb, usesuper, userepl, usebypassrls FROM pg_shadow WHERE usename='#{db_user_safe}'"
    values = do_shell_out(
      %(/opt/gitlab/bin/#{service_cmd} -d template1 -c "#{query}" -tA)
    ).stdout.chomp.split('|').map { |v| v == 't' }
    options = %w(CREATEDB SUPERUSER REPLICATION BYPASSRLS)
    Hash[options.zip(values)]
  end

  def user_options_set?(db_user, options)
    active_options = user_options(db_user)
    options.map(&:upcase).each do |option|
      if option =~ /^NO(.*)/
        return false if active_options[$1]
      else
        return false if !active_options[option]
      end
   end
   true
  end

  def user_hashed_password(db_user)
    db_user_safe = db_user.scan(/[a-z_][a-z0-9_-]*[$]?/).first
    do_shell_out(
      %(/opt/gitlab/bin/#{service_cmd} -d template1 -c "SELECT passwd FROM pg_shadow WHERE usename='#{db_user_safe}'" -tA)
    ).stdout.chomp
  end

  def user_password_match?(db_user, db_pass)
    if db_pass.nil? || /^md5.{32}$/.match(db_pass)
      # if the password is in the MD5 hashed format or is empty, do a simple compare
      db_pass.to_s == user_hashed_password(db_user)
    else
      # if password is in plain-text, convert to MD5 format before doing comparison
      hashed = Digest::MD5.hexdigest("#{db_pass}#{db_user}")
      "md5#{hashed}" == user_hashed_password(db_user)
    end
  end

  def is_slave?
    psql_cmd(["-d 'template1'",
      "-c 'select pg_is_in_recovery()' -A",
      "|grep -x t"])
  end

  # Returns an array of function names for the given database
  #
  # Uses the  `\df` PostgreSQL command to generate a list of functions and their
  # attributes, then cuts out only the function names.
  #
  # @param database [String] the name of the database
  # @return [Array] the list of functions associated with the database
  def list_functions(database)
    do_shell_out(
      %(/opt/gitlab/bin/#{service_cmd} -d #{database} -c '\\df' -tA -F, | cut -d, -f2)
    ).stdout.split("\n")
  end

  def has_function?(database, function)
    list_functions(database).include?(function)
  end

  def bootstrapped?
    File.exists?(File.join(node['gitlab'][service_name]['data_dir'], 'PG_VERSION'))
  end

  def psql_cmd(cmd_list)
    cmd = ["/opt/gitlab/bin/#{service_cmd}", cmd_list.join(' ')].join(' ')
    success?(cmd)
  end

  def version
    VersionHelper.version('/opt/gitlab/embedded/bin/psql --version').split.last
  end

  def database_version
    version_file = "#{@node['gitlab'][service_name]['data_dir']}/PG_VERSION"
    if File.exist?(version_file)
      File.read(version_file).chomp
    else
      nil
    end
  end

  def pg_shadow_lookup
    <<-EOF
    CREATE OR REPLACE FUNCTION public.pg_shadow_lookup(in i_username text, out username text, out password text) RETURNS record AS $$
    BEGIN
        SELECT usename, passwd FROM pg_catalog.pg_shadow
        WHERE usename = i_username INTO username, password;
        RETURN;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    REVOKE ALL ON FUNCTION public.pg_shadow_lookup(text) FROM public, pgbouncer;
    GRANT EXECUTE ON FUNCTION public.pg_shadow_lookup(text) TO pgbouncer;
    EOF
  end

  def service_name
    raise NotImplementedError
  end

  def service_cmd
    raise NotImplementedError
  end
end
