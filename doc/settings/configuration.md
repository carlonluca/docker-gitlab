---
stage: Enablement
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
---

# Configuration options **(FREE SELF)**

GitLab is configured by setting the relevant options in
`/etc/gitlab/gitlab.rb`. See [package defaults](https://docs.gitlab.com/ee/administration/package_information/defaults.html)
for a list of default settings and visit the
[`gitlab.rb.template`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)
for a complete list of available options.
New installations starting from GitLab 7.6, will have
all the options of the template as of installation listed in
`/etc/gitlab/gitlab.rb` by default.

## Configuring the external URL for GitLab

NOTE:
Before you change the external URL, determine if you have previously
defined a custom **Home page URL** or **After sign-out path** by
selecting **Menu >** **{admin}** **Admin** in the top bar, and on the left
sidebar selecting **Settings > General > Sign-in restrictions**. If URLs are
defined, either update them or remove them completely. Both of these settings
might cause unintentional redirecting after configuring a new external URL.

For GitLab to display correct repository clone links to your users,
it needs to know the URL under which it is reached by your users, e.g.
`http://gitlab.example.com`. Add or edit the following line in
`/etc/gitlab/gitlab.rb`:

```ruby
external_url "http://gitlab.example.com"
```

for the change to take effect, run:

```shell
sudo gitlab-ctl reconfigure
```

NOTE:
After you change the external URL, it is recommended that you also
[invalidate the Markdown cache](https://docs.gitlab.com/ee/administration/invalidate_markdown_cache.html).

Please see our [DNS documentation](dns.md) for more details about the use of DNS in a self-managed GitLab instance.

### Specifying the external URL at the time of installation

To make it easier to get a GitLab instance up and running with the minimum
number of commands, `omnibus-gitlab` supports the use of an environment variable
`EXTERNAL_URL` during the package installation. On detecting the presence of
this environment variable, its value will be written as `external_url` in the
`gitlab.rb` file as part of package installation (or upgrade).

NOTE:
`EXTERNAL_URL` environment variable only affects installation/upgrade
of packages. For regular `sudo gitlab-ctl reconfigure` runs, the value present
in `/etc/gitlab/gitlab.rb` will be used.

NOTE:
As part of package updates, if you have `EXTERNAL_URL` variable set
inadvertently, it will replace the existing value in `/etc/gitlab/gitlab.rb`
without any warning. So, it is recommended not to set the variable globally, but
pass it specifically to the installation command:

```shell
sudo EXTERNAL_URL="https://gitlab.example.com" apt-get install gitlab-ee
```

## Configuring a relative URL for GitLab

NOTE:
Relative URL support in Omnibus GitLab is **experimental** and was
[introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/590)
in version 8.5. For source installations, there is a
[separate document](https://docs.gitlab.com/ee/install/relative_url.html).

---

While it is recommended to install GitLab in its own (sub)domain, sometimes
this is not possible due to a variety of reasons. In that case, GitLab can also
be installed under a relative URL, for example, `https://example.com/gitlab`.

Note that by changing the URL, all remote URLs will change, so you'll have to
manually edit them in any local repository that points to your GitLab instance.

### Relative URL requirements

_Starting with 8.17 packages, there is **no need to recompile assets**._

The Omnibus GitLab package is shipped with pre-compiled assets (CSS, JavaScript,
fonts, etc.). If you are running a package _before 8.17_ and you configure
Omnibus with a relative URL, the assets will need to be recompiled, which is a
task that consumes a lot of CPU and memory resources. To avoid out-of-memory
errors, you should have at least 2GB of RAM available on your system, while we
recommend 4GB RAM, and 4 or 8 CPU cores.

### Enable relative URL in GitLab

Follow the steps below to enable relative URL in GitLab:

1. (Optional) If you run short on resources, you can temporarily free up some
   memory by shutting down Puma and Sidekiq with the following
   command:

   ```shell
   sudo gitlab-ctl stop puma
   sudo gitlab-ctl stop sidekiq
   ```

1. Set the `external_url` in `/etc/gitlab/gitlab.rb`:

   ```ruby
   external_url "https://example.com/gitlab"
   ```

   In this example, the relative URL under which GitLab will be served will be
   `/gitlab`. Change it to your liking.

1. Reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

1. Restart the services so that Sidekiq picks up the changes

   ```shell
   sudo gitlab-ctl restart
   ```

If you stumble upon any issues, see the [troubleshooting section](#relative-url-troubleshooting).

### Disable relative URL in GitLab

To disable the relative URL, follow the same steps as above and set up the
`external_url` to a one that doesn't contain a relative path.

If you stumble upon any issues, see the [troubleshooting section](#relative-url-troubleshooting).

### Relative URL troubleshooting

If you notice any issues with GitLab assets appearing broken after moving to a
relative URL configuration (like missing images or unresponsive components),
please raise an issue in [GitLab](https://gitlab.com/gitlab-org/gitlab)
with the `Frontend` label.

If you are running a version _before 8.17_ and for some reason, the asset
compilation step fails (i.e. the server runs out of memory), you can execute
the task manually after you addressed the issue (e.g. add swap):

```shell
sudo NO_PRIVILEGE_DROP=true USE_DB=false gitlab-rake assets:clean assets:precompile
sudo chown -R git:git /var/opt/gitlab/gitlab-rails/tmp/cache
```

User and path might be different if you changed the defaults of
`user['username']`, `user['group']` and `gitlab_rails['dir']` in `gitlab.rb`.
In that case, make sure that the `chown` command above is run with the right
username and group.

## Loading external configuration file from non-root user

Omnibus GitLab package loads all configuration from `/etc/gitlab/gitlab.rb` file.
This file has strict file permissions and is owned by the `root` user. The reason for strict permissions
and ownership is that `/etc/gitlab/gitlab.rb` is being executed as Ruby code by the `root` user during `gitlab-ctl reconfigure`. This means
that users who have to write access to `/etc/gitlab/gitlab.rb` can add configuration that will be executed as code by `root`.

In certain organizations, it is allowed to have access to the configuration files but not as the root user.
You can include an external configuration file inside `/etc/gitlab/gitlab.rb` by specifying the path to the file:

```ruby
from_file "/home/admin/external_gitlab.rb"

```

Please note that code you include into `/etc/gitlab/gitlab.rb` using `from_file` will run with `root` privileges when you run `sudo gitlab-ctl reconfigure`.
Any configuration that is set in `/etc/gitlab/gitlab.rb` after `from_file` is included will take precedence over the configuration from the included file.

## Storing Git data in an alternative directory

By default, Omnibus GitLab stores the Git repository data under
`/var/opt/gitlab/git-data`. The repositories are stored in a subfolder
`repositories`. You can change the location of
the `git-data` parent directory by adding the following line to
`/etc/gitlab/gitlab.rb`.

```ruby
git_data_dirs({ "default" => { "path" => "/mnt/nas/git-data" } })
```

You can also add more than one Git data directory by
adding the following lines to `/etc/gitlab/gitlab.rb` instead.

```ruby
git_data_dirs({
  "default" => { "path" => "/var/opt/gitlab/git-data" },
  "alternative" => { "path" => "/mnt/nas/git-data" }
})
```

If you're running Gitaly on its own server remember to also include the
`gitaly_address` for each Git data directory. See [the documentation on
configuring Gitaly](https://docs.gitlab.com/ee/administration/gitaly/configure_gitaly.html#configure-gitaly-clients).

Note that the target directories and any of its subpaths must not be a symlink.

Run `sudo gitlab-ctl reconfigure` for the changes to take effect.

If you already have existing Git repositories in `/var/opt/gitlab/git-data` you
can move them to the new location as follows:

```shell
# Prevent users from writing to the repositories while you move them.
sudo gitlab-ctl stop

# Note there is _no_ slash behind 'repositories', but there _is_ a
# slash behind 'git-data'.
sudo rsync -av --delete /var/opt/gitlab/git-data/repositories /mnt/nas/git-data/

# Start the necessary processes and run reconfigure to fix permissions
# if necessary
sudo gitlab-ctl reconfigure

# Double-check directory layout in /mnt/nas/git-data. Expected output:
# repositories
sudo ls /mnt/nas/git-data/

# Done! Start GitLab and verify that you can browse through the repositories in
# the web interface.
sudo gitlab-ctl start
```

If you're not looking to move all repositories, but instead want to move specific
projects between existing repository storages, use the
[Edit Project API](https://docs.gitlab.com/ee/api/projects.html#edit-project)
endpoint and specify the `repository_storage` attribute.

## Changing the name of the Git user / group

By default, Omnibus GitLab uses the user name `git` for Git GitLab Shell login,
ownership of the Git data itself, and SSH URL generation on the web interface.
Similarly, the `git` group is used for group ownership of the Git data.

We do not recommend changing the user/group of an existing installation because it can cause unpredictable side-effects.
If you still want to do change the user and group, you can do so by adding the following lines to
`/etc/gitlab/gitlab.rb`.

```ruby
user['username'] = "gitlab"
user['group'] = "gitlab"
```

Run `sudo gitlab-ctl reconfigure` for the change to take effect.

Note that if you are changing the username of an existing installation, the reconfigure run won't change the ownership of the nested directories so you will have to do that manually. Make sure that the new user can access `repositories` as well as the `uploads` directory.

## Specify numeric user and group identifiers

Omnibus GitLab creates users for GitLab, PostgreSQL, Redis and NGINX. You can
specify the numeric identifiers for these users in `/etc/gitlab/gitlab.rb` as
follows.

```ruby
user['uid'] = 1234
user['gid'] = 1234
postgresql['uid'] = 1235
postgresql['gid'] = 1235
redis['uid'] = 1236
redis['gid'] = 1236
web_server['uid'] = 1237
web_server['gid'] = 1237
registry['uid'] = 1238
registry['gid'] = 1238
mattermost['uid'] = 1239
mattermost['gid'] = 1239
prometheus['uid'] = 1240
prometheus['gid'] = 1240
```

Run `sudo gitlab-ctl reconfigure` for the changes to take effect.

If you're changing `user['uid']` and `user['gid']`, you should make sure to update the uid/guid of any files not managed by Omnibus directly, for example logs:

```shell
find /var/log/gitlab -uid <old_uid> | xargs -I:: chown git ::
find /var/log/gitlab -gid <old_uid> | xargs -I:: chgrp git ::
find /var/opt/gitlab -uid <old_uid> | xargs -I:: chown git ::
find /var/opt/gitlab -gid <old_uid> | xargs -I:: chgrp git ::
```

## Disable user and group account management

By default, Omnibus GitLab takes care of creating system user and group accounts
as well as keeping the information updated.
These system accounts run various components of the package.
Most users do not need to change this behavior.
However, if your system accounts are managed by other software, eg. LDAP, you
might need to disable account management done by the package.

To disable user and group accounts management, in `/etc/gitlab/gitlab.rb` set:

```ruby
manage_accounts['enable'] = false
```

**Warning** Omnibus GitLab still expects users and groups to exist on the system where the Omnibus GitLab package is installed.

By default, Omnibus GitLab package expects that following users exist:

```shell
# GitLab user (required)
git

# Web server user (required)
gitlab-www

# Redis user for GitLab (only when using packaged Redis)
gitlab-redis

# Postgresql user (only when using packaged Postgresql)
gitlab-psql

# Prometheus user for prometheus monitoring and various exporters
gitlab-prometheus

# GitLab Mattermost user (only when using GitLab Mattermost)
mattermost

# GitLab Registry user (only when using GitLab Registry)
registry

# GitLab Consul user (only when using GitLab Consul)
gitlab-consul
```

By default, Omnibus GitLab package expects that following groups exist:

```shell
# GitLab group (required)
git

# Web server group (required)
gitlab-www

# Redis group for GitLab (only when using packaged Redis)
gitlab-redis

# Postgresql group (only when using packaged Postgresql)
gitlab-psql

# Prometheus user for prometheus monitoring and various exporters
gitlab-prometheus

# GitLab Mattermost group (only when using GitLab Mattermost)
mattermost

# GitLab Registry group (only when using GitLab Registry)
registry

# GitLab Consul group (only when using GitLab Consul)
gitlab-consul
```

You can also use different user/group names but then you must specify user/group details in `/etc/gitlab/gitlab.rb`, eg.

```ruby
# Do not manage user/group accounts
manage_accounts['enable'] = false

# GitLab
user['username'] = "custom-gitlab"
user['group'] = "custom-gitlab"
user['shell'] = "/bin/sh"
user['home'] = "/var/opt/custom-gitlab"

# Web server
web_server['username'] = 'webserver-gitlab'
web_server['group'] = 'webserver-gitlab'
web_server['shell'] = '/bin/false'
web_server['home'] = '/var/opt/gitlab/webserver'

# Postgresql (not needed when using external Postgresql)
postgresql['username'] = "postgres-gitlab"
postgresql['group'] = "postgres-gitlab"
postgresql['shell'] = "/bin/sh"
postgresql['home'] = "/var/opt/postgres-gitlab"

# Redis (not needed when using external Redis)
redis['username'] = "redis-gitlab"
redis['group'] = "redis-gitlab"
redis['shell'] = "/bin/false"
redis['home'] = "/var/opt/redis-gitlab"

# And so on for users/groups for GitLab Mattermost
```

### Moving the home directory for a user

NOTE:
For the GitLab user, it is recommended that the home directory
is set in local disk (ie not NFS) for better performance. When setting it in
NFS, Git requests will need to make another network request to read the Git
configuration and will increase latency in Git operations.

To move an existing home directory, GitLab services will need to be stopped and some downtime is required.

1. Stop GitLab

   ```shell
   gitlab-ctl stop
   ```

1. Stop the runit server

   ```shell
   # Using systemctl (Debian => 9 - Stretch):
   sudo systemctl stop gitlab-runsvdir

   # Using systemd (CentOS, Ubuntu >= 18.04):
   systemctl stop gitlab-runsvdir.service
   ```

1. Change the home directory. If you had existing data you will need to manually copy/rsync it to these new locations.

   ```shell
   usermod -d /path/to/home USER
   ```

1. Change the configuration setting in your `gitlab.rb`

   ```ruby
   user['home'] = "/var/opt/custom-gitlab"
   ```

1. Start the runit server

   ```shell
   # Using systemctl (Debian => 9 - Stretch):
   sudo systemctl start gitlab-runsvdir

   # Using systemd (CentOS, Ubuntu >= 18.04):
   systemctl start gitlab-runsvdir.service
   ```

1. Run a reconfigure

   ```shell
   gitlab-ctl reconfigure
   ```

If the runnit service is not stopped and the home directories are not manually
moved for the user, GitLab will encounter an error while reconfiguring:

```plaintext
account[GitLab user and group] (gitlab::users line 28) had an error: Mixlib::ShellOut::ShellCommandFailed: linux_user[GitLab user and group] (/opt/gitlab/embedded/cookbooks/cache/cookbooks/package/resources/account.rb line 51) had an error: Mixlib::ShellOut::ShellCommandFailed: Expected process to exit with [0], but received '8'
---- Begin output of ["usermod", "-d", "/var/opt/gitlab", "git"] ----
STDOUT:
STDERR: usermod: user git is currently used by process 1234
---- End output of ["usermod", "-d", "/var/opt/gitlab", "git"] ----
Ran ["usermod", "-d", "/var/opt/gitlab", "git"] returned 8

```

Please make sure to follow the above instructions to avoid this
issue.

## Disable storage directories management

The Omnibus GitLab package takes care of creating all the necessary directories
with the correct ownership and permissions, as well as keeping this updated.

Some of these directories will hold to large amounts of data so in certain setups,
these directories will most likely be mounted on an NFS (or some other) share.

Some types of mounts won't allow automatic creation of directories by the root user
 (default user for initial setup), eg. NFS with `root_squash` enabled on the
share. To work around this the Omnibus GitLab package will attempt to create
these directories using the directory's owner user.

If you have the `/etc/gitlab` directory mounted, you can turn off the management of
that directory.

In `/etc/gitlab/gitlab.rb` set:

```ruby
manage_storage_directories['manage_etc'] = false
```

If you are mounting all GitLab storage directories, each on a separate mount,
you should completely disable the management of storage directories.

To disable management of these directories,
in `/etc/gitlab/gitlab.rb` set:

```ruby
manage_storage_directories['enable'] = false
```

**Warning** The Omnibus GitLab package still expects these directories to exist
on the file system. It is up to the administrator to create and set correct
permissions if this setting is set.

Enabling this setting will prevent the creation of the following directories:

| Default location                                       | Permissions | Ownership        | Purpose |
|--------------------------------------------------------|-------------|------------------|---------|
| `/var/opt/gitlab/git-data`                             | `0700`        | `git:git`        | Holds repositories directory |
| `/var/opt/gitlab/git-data/repositories`                | `2770`        | `git:git`        | Holds Git repositories |
| `/var/opt/gitlab/gitlab-rails/shared`                  | `0751`        | `git:gitlab-www` | Holds large object directories |
| `/var/opt/gitlab/gitlab-rails/shared/artifacts`        | `0700`        | `git:git`        | Holds CI artifacts |
| `/var/opt/gitlab/gitlab-rails/shared/external-diffs`   | `0700`        | `git:git`        | Holds external merge request diffs |
| `/var/opt/gitlab/gitlab-rails/shared/lfs-objects`      | `0700`        | `git:git`        | Holds LFS objects |
| `/var/opt/gitlab/gitlab-rails/shared/packages`         | `0700`        | `git:git`        | Holds package repository |
| `/var/opt/gitlab/gitlab-rails/shared/dependency_proxy` | `0700`        | `git:git`        | Holds dependency proxy |
| `/var/opt/gitlab/gitlab-rails/shared/terraform_state`  | `0700`        | `git:git`        | Holds terraform state |
| `/var/opt/gitlab/gitlab-rails/shared/pages`            | `0750`        | `git:gitlab-www` | Holds user pages |
| `/var/opt/gitlab/gitlab-rails/uploads`                 | `0700`        | `git:git`        | Holds user attachments |
| `/var/opt/gitlab/gitlab-ci/builds`                     | `0700`        | `git:git`        | Holds CI build logs |
| `/var/opt/gitlab/.ssh`                                 | `0700`        | `git:git`        | Holds authorized keys |

## Only start Omnibus GitLab services after a given file system is mounted

If you want to prevent Omnibus GitLab services (NGINX, Redis, Puma, etc.)
from starting before a given file system is mounted, add the following to
`/etc/gitlab/gitlab.rb`:

```ruby
# wait for /var/opt/gitlab to be mounted
high_availability['mountpoint'] = '/var/opt/gitlab'
```

Run `sudo gitlab-ctl reconfigure` for the change to take effect.

## Configuring runtime directory

When Prometheus monitoring is enabled, GitLab Exporter will conduct measurements
of each Puma process (Rails metrics). Every Puma process will need to write
a metrics file to a temporary location for each controller request.
Prometheus will then collect all these files and process their values.

To avoid creating disk I/O, the Omnibus GitLab package will use a
runtime directory.

During `reconfigure`, the package will check if `/run` is a `tmpfs` mount.
If it is not, the warning will be printed:

```plaintext
Runtime directory '/run' is not a tmpfs mount.
```

and Rails metrics will be disabled.

To enable Rails metrics again, create a `tmpfs` mount and specify it in `/etc/gitlab/gitlab.rb`:

```ruby
runtime_dir '/path/to/tmpfs'
```

NOTE:
Please note that there is no `=` in the configuration.

Run `sudo gitlab-ctl reconfigure` for the settings to take effect.

## Configure a failed authentication ban

You can configure a [failed authentication ban](https://docs.gitlab.com/ee/security/rate_limits.html#failed-authentication-ban-for-git-and-container-registry)
for Git and the container registry.

1. Open `/etc/gitlab/gitlab.rb` with your editor.
1. Add the following:

   ```ruby
   gitlab_rails['rack_attack_git_basic_auth'] = {
     'enabled' => true,
     'ip_whitelist' => ["127.0.0.1"],
     'maxretry' => 10, # Limit the number of Git HTTP authentication attempts per IP
     'findtime' => 60, # Reset the auth attempt counter per IP after 60 seconds
     'bantime' => 3600 # Ban an IP for one hour (3600s) after too many auth attempts
   }
   ```

1. Reconfigure GitLab:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

The following settings can be configured:

- `enabled`: By default this is set to `false`. Set this to `true` to enable Rack Attack.
- `ip_whitelist`: IPs to not block. They must be formatted as strings within a
  Ruby array. CIDR notation is supported in GitLab 12.1 and later.
  For example, `["127.0.0.1", "127.0.0.2", "127.0.0.3", "192.168.0.1/24"]`.
- `maxretry`: The maximum amount of times a request can be made in the
  specified time.
- `findtime`: The maximum amount of time that failed requests can count against an IP
  before it's added to the denylist (in seconds).
- `bantime`: The total amount of time that an IP is blocked (in seconds).

## Disabling automatic cache cleaning during installation

If you have large GitLab installation, you might not want to run a `rake cache:clear` task.
As it can take a long time to finish. By default, the cache clear task will run automatically
during reconfigure.

Edit `/etc/gitlab/gitlab.rb`:

```ruby
# This is an advanced feature used by large gitlab deployments where loading
# whole RAILS env takes a lot of time.
gitlab_rails['rake_cache_clear'] = false
```

Don't forget to remove the `#` comment characters at the beginning of this
line.

## Disable impersonation

Disabling impersonation is documented in
[the API docs](https://docs.gitlab.com/ee/api/index.html#disable-impersonation).

## Error Reporting and Logging with Sentry

[Sentry](https://sentry.io) is an error reporting and logging tool which can be
used as SaaS or on premise. It's Open Source, and you can [browse its source code
repositories](https://github.com/getsentry).

The following settings can be used to configure Sentry:

```ruby
gitlab_rails['sentry_enabled'] = true
gitlab_rails['sentry_dsn'] = 'https://<key>@sentry.io/<project>'
gitlab_rails['sentry_clientside_dsn'] = 'https://<key>@sentry.io/<project>'
gitlab_rails['sentry_environment'] = 'production'
```

The [Sentry Environment](https://docs.sentry.io/product/sentry-basics/environments/)
can be used to track errors and issues across several deployed GitLab
environments, e.g. lab, development, staging, production.

To set custom [Sentry tags](https://docs.sentry.io/product/sentry-basics/guides/enrich-data/)
on every event sent from a particular server, the `GITLAB_SENTRY_EXTRA_TAGS`
environment variable can be set. This is a JSON-encoded hash representing any
tags that should be passed to Sentry for all exceptions from that server.

For instance, setting:

```ruby
gitlab_rails['env'] = {
  'GITLAB_SENTRY_EXTRA_TAGS' => '{"stage": "main"}'
}
```

Would add the 'stage' tag with a value of 'main'.

## Content Security Policy

Setting a Content Security Policy (CSP) can help thwart JavaScript
cross-site scripting (XSS) attacks. See [the Mozilla documentation on
CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP) for more
details.

GitLab 12.2 added support for [CSP and nonces with inline
JavaScript](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src).
It is [not configured on by default
yet](https://gitlab.com/gitlab-org/gitlab/-/issues/30720). An example
configuration that will work for most installations of GitLab is below:

```ruby
gitlab_rails['content_security_policy'] = {
    enabled: true,
    report_only: false,
    directives: {
      default_src: "'self'",
      script_src: "'self' 'unsafe-inline' 'unsafe-eval' https://www.recaptcha.net https://apis.google.com",
      frame_ancestors: "'self'",
      frame_src: "'self' https://www.recaptcha.net/ https://content.googleapis.com https://content-compute.googleapis.com https://content-cloudbilling.googleapis.com https://content-cloudresourcemanager.googleapis.com",
      img_src: "* data: blob:",
      style_src: "'self' 'unsafe-inline'"
    }
}
```

Improperly configuring the CSP rules could prevent GitLab from working
properly. Before rolling out a policy, you may also want to change
`report_only` to `true` to test the configuration.

## Setting initial root password on installation

The initial password for the user `root` can be set at the installation time with the environment variable `GITLAB_ROOT_PASSWORD`.

For example:

```shell
GITLAB_ROOT_PASSWORD="<strongpassword>" EXTERNAL_URL="http://gitlab.example.com" apt install gitlab-ee
```

## Setting allowed hosts to prevent host header attacks

To prevent GitLab from accepting a host header other than
what's intended:

1. Edit `/etc/gitlab/gitlab.rb` and configure `allowed_hosts`:

   ```ruby
   gitlab_rails['allowed_hosts'] = ['gitlab.example.com']
   ```

1. Reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

There are no known security issues in GitLab caused by not configuring `allowed_hosts`,
but it's recommended for defense in depth against potential [host header attacks](https://portswigger.net/web-security/host-header).

## Setting up LDAP sign-in

See [LDAP setup documentation](https://docs.gitlab.com/ee/administration/auth/ldap/index.html).

## Smartcard authentication

See [Smartcard documentation](https://docs.gitlab.com/ee/administration/auth/smartcard.html).

## Enable HTTPS

See [NGINX documentation](nginx.md#enable-https).

### Redirect `HTTP` requests to `HTTPS`

See [NGINX documentation](nginx.md#redirect-http-requests-to-https).

### Change the default port and the SSL certificate locations

See
[NGINX documentation](nginx.md#change-the-default-port-and-the-ssl-certificate-locations).

## Use non-packaged web-server

For using an existing NGINX, Passenger, or Apache webserver see [NGINX documentation](nginx.md#using-a-non-bundled-web-server).

## Using a non-packaged PostgreSQL database management server

To connect to an external PostgreSQL DBMS see [doc/settings/database.md](database.md)

## Using a non-packaged Redis instance

See [Redis documentation](redis.md).

## Adding ENV Vars to the GitLab Runtime Environment

See
[doc/settings/environment-variables.md](environment-variables.md).

## Changing GitLab.yml settings

See [`gitlab.yml` documentation](gitlab.yml.md).

## Sending application email via SMTP

See [SMTP configuration documentation](smtp.md).

## OmniAuth (Google, Twitter, GitHub login)

See [OmniAuth documentation](https://docs.gitlab.com/ee/integration/omniauth.html).

## Adjusting Puma settings

See [Puma documentation](https://docs.gitlab.com/ee/administration/operations/puma.html)

## Setting the NGINX listen address or addresses

See [NGINX documentation](nginx.md).

## Inserting custom NGINX settings into the GitLab server block

See [NGINX documentation](nginx.md).

## Inserting custom settings into the NGINX config

See [NGINX documentation](nginx.md).

## Enable nginx_status

See [NGINX documentation](nginx.md).

## Pseudonymizer settings

See [Pseudonymizer documentation](https://docs.gitlab.com/ee/administration/pseudonymizer.html).
