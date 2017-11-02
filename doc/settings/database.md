# Database settings

>**Note:**
Omnibus GitLab has a bundled PostgreSQL server and PostgreSQL is the preferred
database for GitLab.

GitLab supports the following database management systems:

- PostgreSQL
- MySQL/MariaDB

Thus you have three options for database servers to use with Omnibus GitLab:

- Use the packaged PostgreSQL server included with GitLab Omnibus (no configuration required, recommended)
- Use an [external PostgreSQL server](#using-a-non-packaged-postgresql-database-management-server)
- Use an [external MySQL server with Enterprise Edition package](#using-a-mysql-database-management-server-enterprise-edition-only) (deprecated)

If you are planning to use MySQL/MariaDB, make sure to read the [introductory
paragraph](#using-a-mysql-database-management-server-enterprise-edition-only)
before proceeding, as it contains some useful information.

## Enabling SSL

To enable SSL, you first need to have a number of files:

1. The public SSL certificate for the database (`server.crt`).
2. The corresponding private key for the SSL certificate (`server.key`).
3. Optional: A root certificate bundle that validates the server's certificate
(`root.crt`). By default, Omnibus GitLab will use the embedded certificate
bundle in `/opt/gitlab/embedded/ssl/certs/cacert.pem`.

Note that the location of these files can be configurable, but the private key
MUST be readable by the `gitlab-psql` user. Note that private keys stored in
`/etc/gitlab/ssl` currently cannot be read by this user, so the key may need
to be copied to another location and assigned the proper permissions.

For more details, see the [PostgreSQL documentation](https://www.postgresql.org/docs/9.6/static/ssl-tcp.html).

Note that `server.crt` and `server.key` may be different from the default SSL
certificates used to access GitLab. For example, suppose the external hostname
of your database is `database.example.com`, and your external GitLab hostname
is `gitlab.example.com`. You will either need a wildcard certificate for
`*.example.com` or two different SSL certificates.

With these files in hand, enable SSL:

1. Edit `/etc/gitlab/gitlab.rb`:

    ```ruby
    postgresql['ssl'] = 'on'
    ```

    Note that this does NOT enforce SSL connections on the server side. Enforcing SSL
    requires using the `hostssl` configuration in `pg_hba.conf`. See https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html
    for more details.

1. Optional: Customize the location of the required SSL files in `/etc/gitlab/gitlab.rb`. For example:

    ```ruby
    postgresql['ssl_cert_file'] = 'server.crt'
    postgresql['ssl_key_file'] = 'server.key'
    postgresql['ssl_ca_file'] = '/opt/gitlab/embedded/ssl/certs/cacert.pem'
    ```

    Using a relative path will cause PostgreSQL to look inside its data
    directory (`/var/opt/gitlab/postgresql/data` by default).

1. Optional: Copy the required SSL files into the PostgreSQL data directory. For example:

    ```sh
    cp server.crt server.key /var/opt/gitlab/postgresql/data
    cd /var/opt/gitlab/postgresql/data
    chown gitlab-psql:gitlab-psql server.crt server.key
    ```

    Note that the PostgreSQL user (by default `gitlab-psql`) must have read access to these files,
    or PostgreSQL will fail to start.

1. [Reconfigure GitLab][] to apply the configuration changes.

1. Restart PostgreSQL for the changes to take effect:

    ```sh
    gitlab-ctl restart postgresql
    ```

   If PostgreSQL fails to start, check the logs
   (e.g. `/var/log/gitlab/postgresql/current`) for more details.

### Verifying that SSL is being used

To check whether SSL is being used by clients, you can run:

```sh
gitlab-rails dbconsole
```

At startup, you should see a banner as the following:

```
psql (9.6.5)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: on)
Type "help" for help.
```

To check whether clients are using SSL, you can issue this SQL query:

```sql
SELECT * FROM pg_stat_ssl;
```

For example:

```
gitlabhq_production=> SELECT * FROM pg_stat_ssl;
  pid  | ssl | version |           cipher            | bits | compression | clientdn
-------+-----+---------+-----------------------------+------+-------------+----------
 47506 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47509 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47510 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47527 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47528 | f   |         |                             |      |             |
 47537 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47560 | f   |         |                             |      |             |
 47561 | f   |         |                             |      |             |
 47563 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47564 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47565 | f   |         |                             |      |             |
 47569 | f   |         |                             |      |             |
 47570 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47573 | f   |         |                             |      |             |
 47585 | f   |         |                             |      |             |
 47586 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47618 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 47628 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
 55812 | t   | TLSv1.2 | ECDHE-RSA-AES256-GCM-SHA384 |  256 | t           |
(19 rows)
```

Rows that have `t` listed under the `ssl` column are enabled.

## Enabling PostgreSQL WAL (Write Ahead Log) Archiving

By default WAL archiving of the packaged PostgreSQL is not enabled. Please consider the following when
seeking to enable WAL archiving:

- The WAL level needs to be 'replica' or higher (9.6+ options are `minimal`, `replica`, or `logical`)
- Increasing the WAL level will increase the amount of storage consumed in regular operations

To enable WAL Archiving:

1. Edit `/etc/gitlab/gitlab.rb`:
    ```ruby
    # Replication settings
    postgresql['sql_replication_user'] = "gitlab_replicator"
    postgresql['wal_level'] = "replica"
        ...
        ...
    # Backup/Archive settings
    postgresql['archive_mode'] = "on"
    postgresql['archive_command'] = "/your/wal/archiver/here"
    postgresql['archive_timeout'] = "60"
    ```

1.  [Reconfigure GitLab][] for the changes to take effect. This will result in a database restart.

## Using a non-packaged PostgreSQL database management server

By default, GitLab is configured to use the PostgreSQL server that is included
in Omnibus GitLab. You can also reconfigure it to use an external instance of
PostgreSQL.

**WARNING** If you are using non-packaged PostgreSQL server, you need to make
sure that PostgreSQL is set up according to the [database requirements document].

1.  Edit `/etc/gitlab/gitlab.rb`:

    ```ruby
    # Disable the built-in Postgres
    postgresql['enable'] = false

    # Fill in the connection details for database.yml
    gitlab_rails['db_adapter'] = 'postgresql'
    gitlab_rails['db_encoding'] = 'utf8'
    gitlab_rails['db_host'] = '127.0.0.1'
    gitlab_rails['db_port'] = '5432'
    gitlab_rails['db_username'] = 'USERNAME'
    gitlab_rails['db_password'] = 'PASSWORD'
    ```

    Don't forget to remove the `#` comment characters at the beginning of these
    lines.

    **Note:**
    - `/etc/gitlab/gitlab.rb` should have file permissions `0600` because it contains
    plain-text passwords.
    - Postgresql allows to listen on multiple adresses. See [Postgresql Connection Config#listen_addresses](https://www.postgresql.org/docs/9.5/static/runtime-config-connection.html#listen_addresses)

        If you use multiple addresses in `gitlab_rails['db_host']`, comma-separated, the first address in the list will be used for connection.


1.  [Reconfigure GitLab][] for the changes to take effect.

1.  [Seed the database](#seed-the-database-fresh-installs-only).

### Backup and restore a non-packaged PostgreSQL database

When using the [rake backup create and restore task][rake-backup], GitLab will
attempt to use the packaged `pg_dump` command to create a database backup file
and the packaged `psql` command to restore a backup. This will only work if
they are the correct versions. Check the versions of the packaged `pg_dump` and
`psql`:

```bash
/opt/gitlab/embedded/bin/pg_dump --version
/opt/gitlab/embedded/bin/psql --version
```

If these versions are different from your non-packaged external PostgreSQL
(most likely they are different), you need to add symbolic links to your
non-packaged PostgreSQL:

1. Check the location of the non-packaged executables:

    ```bash
    which pg_dump psql
    ```

    This will output something like:

    ```
    /usr/bin/pg_dump
    /usr/bin/psql
    ```

1.  Add symbolic links to the non-packaged versions:
    ```bash
    ln -s /usr/bin/pg_dump /usr/bin/psql /opt/gitlab/bin/
    ```

1.  Check the versions:

    ```
    /opt/gitlab/bin/pg_dump --version
    /opt/gitlab/bin/psql --version
    ```

    They should now be the same as your non-packaged external PostgreSQL.

After this is done, ensure that the backup and restore tasks are using the
correct executables by running both the [backup][rake-backup] and
[restore][rake-restore] tasks.

## Using a MySQL database management server (Enterprise Edition only)

>**Note:**
Using MySQL with the Omnibus GitLab package is considered deprecated. Although
GitLab Enterprise Edition will still work when MySQL is used, there will be some
limitations as outlined in the [database requirements document].

MySQL in Omnibus GitLab package is only supported in GitLab Enterprise Edition
Starter and Premium. The MySQL server itself is _not_ shipped with Omnibus, you
will have to install it on your own or use an existing one. Omnibus ships only
the MySQL client.

Make sure that GitLab's MySQL database collation is UTF-8, otherwise you could
hit [collation issues][ee-245]. See ['Set MySQL collation to UTF-8']
(#set-mysql-collation-to-utf-8) to fix any relevant errors.

---

The following guide assumes that you want to use MySQL or MariaDB and are using
the **GitLab Enterprise Edition packages**.

>**Important note:**
If you are connecting Omnibus GitLab to an existing GitLab database you should
[create a backup][rake-backup] before attempting this procedure.

1.  First, set up your database server according to the [upstream GitLab
    instructions][mysql-install]. If you want to keep using an existing GitLab
    database you can skip this step.

1.  Next, add the following settings to `/etc/gitlab/gitlab.rb`:

    ```ruby
    # Disable the built-in Postgres
    postgresql['enable'] = false

    # Fill in the values for database.yml
    gitlab_rails['db_adapter'] = 'mysql2'
    gitlab_rails['db_encoding'] = 'utf8'
    gitlab_rails['db_host'] = '127.0.0.1'
    gitlab_rails['db_port'] = '3306'
    gitlab_rails['db_username'] = 'USERNAME'
    gitlab_rails['db_password'] = 'PASSWORD'
    ```

    `db_adapter` and `db_encoding` should be like the example above. Change
    all other settings according to your MySQL setup.

    >**Note:**
    `/etc/gitlab/gitlab.rb` should have file permissions `0600` because it contains
    plain-text passwords.

1.  [Reconfigure GitLab][] for the changes to take effect.

1.  (Optionally) [Seed the database](#seed-the-database-fresh-installs-only).

## Seed the database (fresh installs only)

**This is a destructive command; do not run it on an existing database!**

---

Omnibus GitLab will not automatically seed your external database. Run the
following command to import the schema and create the first admin user:

```shell
# Remove 'sudo' if you are the 'git' user
sudo gitlab-rake gitlab:setup
```

If you want to specify a password for the default `root` user, specify the
`initial_root_password` setting in `/etc/gitlab/gitlab.rb` before running the
`gitlab:setup` command above:

```ruby
gitlab_rails['initial_root_password'] = 'nonstandardpassword'
```

If you want to specify the initial registration token for shared GitLab Runners,
specify the `initial_shared_runners_registration_token` setting in `/etc/gitlab/gitlab.rb`
before running the `gitlab:setup` command:

```ruby
gitlab_rails['initial_shared_runners_registration_token'] = 'token'
```

## Disabling automatic database migration

If you have multiple GitLab servers sharing a database, you will want to limit the
number of nodes that are performing the migration steps during reconfiguration.

Edit `/etc/gitlab/gitlab.rb`:

```ruby
# Enable or disable automatic database migrations
gitlab_rails['auto_migrate'] = false
```

Don't forget to remove the `#` comment characters at the beginning of this
line.

**Note:**
`/etc/gitlab/gitlab.rb` should have file permissions `0600` because it contains
plain-text passwords.

The next time a reconfigure is triggered, the migration steps will not be performed.

## Upgrade packaged PostgreSQL server

**As of GitLab 10.0, PostgreSQL 9.6.X is the only database version in GitLab.**

If you're still running on the bundled PostgreSQL 9.2.18 when you upgrade to GitLab 10.0,
it will fail and remain on your current version.
To ensure you're running the latest version of the bundled PostgreSQL, first upgrade GitLab to the latest 9.5.X release.

If you had previously avoided the upgrade by touching `/etc/gitlab/skip-auto-migrations` this will no longer work.

If you want to manually upgrade without upgrading GitLab, you can follow these instructions:

**Note:**
* Please fully read this section before running any commands.
* Please plan ahead as upgrade involves downtime.
* If you encounter any problems during upgrade, please raise an issue
with a full description at [omnibus-gitlab issue tracker](https://gitlab.com/gitlab-org/omnibus-gitlab).


Before upgrading, please check the following:

* You're currently running the latest version of GitLab and it is working.
* If you recently upgraded, make sure that `sudo gitlab-ctl reconfigure` ran successfully before you proceed.
* You're using the bundled version of PostgreSQL. Look for `postgresql['enable']` to be `true`, commented out, or absent from `/etc/gitlab/gitlab.rb`.
* You haven't already upgraded. Running `sudo gitlab-psql --version` should print `psql (PostgreSQL) 9.2.18`.
* You will need to have sufficient disk space for two copies of your database. **Do not attempt to upgrade unless you have enough free space available.** Check your database size using `sudo du -sh /var/opt/gitlab/postgresql/data` (or update to your database path) and space available using `sudo df -h`. If the partition where the database resides does not have enough space, you can pass the argument `--tmp-dir $DIR` to the command.

Please note:

**This upgrade requires downtime as the database must be down while the upgrade is being performed.
The length of time depends on the size of your database.
If you would rather avoid downtime, it is possible to upgrade to a new database using [Slony](http://www.slony.info/).
Please see our [guide](http://docs.gitlab.com/ce/update/upgrading_postgresql_using_slony.html) on how to perform the upgrade.**

Once you have confirmed that the the above checklist is satisfied,
you can proceed.
To perform the upgrade, run the command:

```
sudo gitlab-ctl pg-upgrade
```

This command performs the following steps:
1. Checks to ensure the database is in a known good state
1. Shuts down the existing database, any unnecessary services, and enables the gitlab deploy page.
1. Changes the symlinks in `/opt/gitlab/embedded/bin/` for PostgreSQL to point to the newer version of the database
1. Creates a new directory containing a new, empty database with a locale matching the existing database
1. Uses the `pg_upgrade` tool to copy the data from the old database to the new database
1. Moves the old database out of the way
1. Moves the new database to the expected location
1. Calls `sudo gitlab-ctl reconfigure` to do the required configuration changes, and start the new database server.
1. Start the remaining services, and remove the deploy page.
1. If any errors are detected during this process, it should immediately revert to the old version of the database.

Once this step is complete, verify everything is working as expected.

**Once you have verified that your GitLab instance is running correctly**,
you can remove the old database with:

```
sudo rm -rf /var/opt/gitlab/postgresql/data.9.2.18
```

### Upgrading a GitLab HA cluster
If you have setup your GitLab instance per the [GitLab HA documentation](https://docs.gitlab.com/ee/administration/high_availability/database.html), upgrade the database server last. It should not be necessary to perform any other extra steps.

You do not need to run `pg-upgrade` on any node besides the database node, but they should be updated to the latest version of GitLab before the database is updated.

#### Troubleshooting upgrades in an HA cluster

* If at some point, the bundled PostgreSQL had been running on a node before upgrading to an HA setup, the old data directory may remain. This will cause `gitlab-ctl reconfigure` to downgrade the version of the PostgreSQL utilities it uses on that node. Move (or remove) the directory to prevent this:
  * `mv /var/opt/gitlab/postgresql/data/ /var/opt/gitlab/postgresql/data.$(date +%s)`

## Downgrade packaged PostgreSQL server

As of GitLab 10.0, the default version of PostgreSQL is 9.6.1, and 9.2.18 is no longer shipped in the package.

If you need to run an older version of PostgreSQL, you must downgrade GitLab to an older version.

## Troubleshooting

### Set MySQL collation to UTF-8

If you are hit by an error similar as described in [this issue][ee-245]
(_Mysql2::Error: Incorrect string value (\`st_diffs\` field)_), you
can change the collation of the faulty table with:

```bash
ALTER TABLE merge_request_diffs default character set = utf8 collate = utf8_unicode_ci;
ALTER TABLE merge_request_diffs convert to character set utf8 collate utf8_unicode_ci;
```

In the above example the affected table is called `merge_request_diffs`.

### Connecting to the bundled PostgreSQL database

If you need to connect to the bundled PostgreSQL database and are
using the default Omnibus GitLab database configuration, you can
connect as the application user:

```bash
sudo gitlab-rails dbconsole
```

or as a Postgres superuser:

```bash
sudo gitlab-psql -d gitlabhq_production
```

[ee-245]: https://gitlab.com/gitlab-org/gitlab-ee/issues/245 "MySQL collation issue"
[rake-backup]: https://docs.gitlab.com/ce/raketasks/backup_restore.html#create-a-backup-of-the-gitlab-system "Backup raketask documentation"
[Reconfigure GitLab]: https://docs.gitlab.com/ce/administration/restart_gitlab.html#omnibus-gitlab-reconfigure "Reconfigure GitLab"
[rake-restore]: https://docs.gitlab.com/ce/raketasks/backup_restore.html#restore-a-previously-created-backup "Restore raketask documentation"
[mysql-install]: https://docs.gitlab.com/ce/install/database_mysql.html "MySQL documentation"
[database requirements document]: https://docs.gitlab.com/ce/install/requirements.html#database
