# Database settings

_**Note:**
Omnibus GitLab has a bundled PostgreSQL server and PostgreSQL is the preferred
database for GitLab._

---

GitLab supports the following database management systems:

- PostgreSQL
- MySQL

Thus you have three options for database servers to use with Omnibus GitLab:

- Use the packaged PostgreSQL server included with GitLab Omnibus (no configuration required, recommended)
- Use an [external PostgreSQL server](#using-a-non-packaged-postgresql-database-management-server)
- Use an [external MySQL server with EE package](#using-a-mysql-database-management-server-enterprise-edition-only)

If you are planning to use MySQL/MariaDB, make sure to read the [MySQL special notes]
(#omnibus-mysql-special-notes) before proceeding.

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
/opt/gitlab/bin/pg_dump --version
/opt/gitlab/bin/psql -- version
```

If these versions are different from your non-packaged external PostgreSQL
(most likely they are different), move them aside and replace them with
symbolic links to your non-packaged PostgreSQL:

1. Check the location of the non-packaged executables:

    ```bash
    which pg_dump psql
    ```

    This will output something like:

    ```
    /usr/bin/pg_dump
    /usr/bin/psql
    ```

1.  Move aside the existing executables and replace them with symbolic links to
    the non-packaged versions:

    ```bash
    cd /opt/gitlab/embedded/bin
    mv psql psql_moved
    mv pg_dump pg_dump_moved
    ln -s /usr/bin/pg_dump /usr/bin/psql /opt/gitlab/embedded/bin/
    ```

1.  Re-check the versions:

    ```
    /opt/gitlab/embedded/bin/pg_dump --version
    /opt/gitlab/embedded/bin/psql --version
    ```

    They should now be the same as your non-packaged external PostgreSQL.

After this is done, ensure that the backup and restore tasks are using the
correct executables by running both the [backup][rake-backup] and
[restore][rake-restore] tasks.

## Omnibus MySQL special notes

MySQL in Omnibus is only supported in GitLab Enterprise Edition.
The MySQL server itself is _not_ shipped with Omnibus, you will have to install
it on your own or use an existing one. Omnibus ships only the MySQL client.

Make sure that GitLab's MySQL database collation is UTF-8, otherwise you could
hit [collation issues][ee-245]. See ['Set MySQL collation to UTF-8']
(#set-mysql-collation-to-utf-8) to fix any relevant errors.

## Using a MySQL database management server (Enterprise Edition only)

_**Important note:**
If you are connecting Omnibus GitLab to an existing GitLab database you should
[create a backup][rake-backup] before attempting this procedure._

---

The following guide assumes that you want to use MySQL or MariaDB and are using
the **GitLab Enterprise Edition packages**.

1.  First, set up your database server according to the [upstream GitLab
    instructions][mysql-install].

    If you want to keep using an existing GitLab database you can skip this step.

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


1.  [Reconfigure GitLab][] for the changes to take effect.

1.  [Seed the database](#seed-the-database-fresh-installs-only).

**Note:**
`/etc/gitlab/gitlab.rb` should have file permissions `0600` because it contains
plain-text passwords.

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

Currently Omnibus GitLab package runs PostgreSQL 9.2.18 by default.
Version 9.6.1 is included as an option for users to manually upgrade.
The next major release will ship with a newer PostgreSQL by default, at which
point reconfigure will not be run until the database is upgraded so please
plan ahead.

A check is performed while installing/upgrading the GitLab omnibus package.
If you're using the bundled PostgreSQL version, you should receive a notice on the
command line if a newer version of PostgreSQL is available.

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
* You will need to have sufficient disk space for two copies of your database. **Do not attempt to upgrade unless you have enough free space available.** If the partition where the database resides does not have enough space (default location is `/var/opt/gitlab/postgresql/data`), you can pass the argument `--tmp-dir $DIR` to the command.

Please note:

**This upgrade requires downtime as the database must be down while the upgrade is being performed.
The length of time entirely depends on the size of your database.**

Once you have confirmed that the the above checklist is satisfied,
you can proceed.
To perform the upgrade, run the command:

```
sudo gitlab-ctl pg-upgrade
```

This command performs the following steps:
1. Checks to ensure the database is in a known good state
1. Shuts down the existing database
1. Changes the symlinks in `/opt/gitlab/embedded/bin/` for PostgreSQL to point to the newer version of the database
1. Creates a new directory containing a new, empty database with a locale matching the existing database
1. Uses the `pg_upgrade` tool to copy the data from the old database to the new database
1. Moves the old database out of the way
1. Moves the new database to the expected location
1. Calls `sudo gitlab-ctl reconfigure` to do the required configuration changes, and start the new database server.
1. If any errors are detected during this process, it should immediately revert to the old version of the database.

Once this step is complete, verify everything is working as expected.

If you run into an issue, and wish to downgrade the version of PostgreSQL, run:

```
sudo gitlab-ctl revert-pg-upgrade
```
Please note:
This will revert your database and data to what was there before you upgraded
the database. Any changes you might have made since the upgrade will be lost.

**Once you have verified that your GitLab instance is running correctly**,
you can remove the old database with:

```
sudo rm -rf /var/opt/gitlab/postgresql/data.9.2.18
```

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
