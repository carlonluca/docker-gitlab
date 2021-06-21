---
stage: Enablement
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
comments: false
---

# Omnibus GitLab Docs **(FREE SELF)**

Omnibus GitLab is a way to package different services and tools required to run GitLab, so that most users can install it without laborious configuration.

## Package information

- [Checking the versions of bundled software](package-information/README.md#checking-the-versions-of-bundled-software)
- [Package defaults](package-information/defaults.md)
- [Components included](https://docs.gitlab.com/ee/development/architecture.html#component-list)
- [Deprecated Operating Systems](package-information/deprecated_os.md)
- [Signed Packages](package-information/signed_packages.md)
- [Deprecation Policy](package-information/deprecation_policy.md)
- [Licenses of bundled dependencies](https://gitlab-org.gitlab.io/omnibus-gitlab/licenses.html)

## Installation

For installation details, see [Installing Omnibus GitLab](installation/index.md).

## Running on a low-resource device (like a Raspberry Pi)

You can run GitLab on supported low-resource computers like the Raspberry Pi 3, but you must tune the settings
to work best with the available resources. Check out the [documentation](settings/rpi.md) for suggestions on what to adjust.

## Maintenance

- [Get service status](maintenance/README.md#get-service-status)
- [Starting and stopping](maintenance/README.md#starting-and-stopping)
- [Invoking Rake tasks](maintenance/README.md#invoking-rake-tasks)
- [Starting a Rails console session](maintenance/README.md#starting-a-rails-console-session)
- [Starting a PostgreSQL superuser `psql` session](maintenance/README.md#starting-a-postgresql-superuser-psql-session)
- [Container registry garbage collection](maintenance/README.md#container-registry-garbage-collection)

## Configuring

- [Configuring the external URL](settings/configuration.md#configuring-the-external-url-for-gitlab)
- [Configuring a relative URL for GitLab (experimental)](settings/configuration.md#configuring-a-relative-url-for-gitlab)
- [Storing Git data in an alternative directory](settings/configuration.md#storing-git-data-in-an-alternative-directory)
- [Changing the name of the Git user group](settings/configuration.md#changing-the-name-of-the-git-user--group)
- [Specify numeric user and group identifiers](settings/configuration.md#specify-numeric-user-and-group-identifiers)
- [Only start Omnibus GitLab services after a given file system is mounted](settings/configuration.md#only-start-omnibus-gitlab-services-after-a-given-file-system-is-mounted)
- [Disable user and group account management](settings/configuration.md#disable-user-and-group-account-management)
- [Disable storage directory management](settings/configuration.md#disable-storage-directories-management)
- [Configuring Rack attack](settings/configuration.md#configuring-rack-attack)
- [SMTP](settings/smtp.md)
- [NGINX](settings/nginx.md)
- [LDAP](https://docs.gitlab.com/ee/administration/auth/ldap.html)
- [Puma](settings/puma.md)
- [ActionCable](settings/actioncable.md)
- [Redis](settings/redis.md)
- [Logs](settings/logs.md)
- [Database](settings/database.md)
- [Reply by email](https://docs.gitlab.com/ee/administration/reply_by_email.html)
- [Environment variables](settings/environment-variables.md)
- [`gitlab.yml`](settings/gitlab.yml.md)
- [Backups](settings/backups.md)
- [Pages](https://docs.gitlab.com/ee/administration/pages/index.html)
- [SSL](settings/ssl.md)
- [GitLab and Registry](architecture/registry/README.md)
- [Configuring an asset proxy server](https://docs.gitlab.com/ee/security/asset_proxy.html)
- [Image scaling](settings/image_scaling.md)

## Updating

- [Upgrade guidance](https://docs.gitlab.com/ee/update/index.html), including [supported upgrade paths](https://docs.gitlab.com/ee/update/index.html#upgrade-paths).
- [Upgrade from Community Edition to Enterprise Edition](update/README.md#update-community-edition-to-enterprise-edition)
- [Update to the latest version](update/README.md#update-using-the-official-repositories)
- [Downgrade to an earlier version](update/README.md#downgrade)
- [Upgrade from a non-Omnibus installation to an Omnibus installation using a backup](update/convert_to_omnibus.md#upgrading-from-non-omnibus-postgresql-to-an-omnibus-installation-using-a-backup)
- [Upgrade from non-Omnibus PostgreSQL to an Omnibus installation in-place](update/convert_to_omnibus.md#upgrading-from-non-omnibus-postgresql-to-an-omnibus-installation-in-place)
- [Upgrade from non-Omnibus MySQL to an Omnibus installation (version 6.8+)](update/convert_to_omnibus.md#upgrading-from-non-omnibus-mysql-to-an-omnibus-installation-version-68)

## Troubleshooting

- [Hash Sum mismatch when downloading packages](common_installation_problems/README.md#hash-sum-mismatch-when-downloading-packages)
- [Apt error: `The requested URL returned error: 403`](common_installation_problems/README.md#apt-error-the-requested-url-returned-error-403).
- [GitLab is unreachable in my browser](common_installation_problems/README.md#gitlab-is-unreachable-in-my-browser).
- [Emails are not being delivered](common_installation_problems/README.md#emails-are-not-being-delivered).
- [Reconfigure freezes at ruby_block[supervise_redis_sleep] action run](common_installation_problems/README.md#reconfigure-freezes-at-ruby_blocksupervise_redis_sleep-action-run).
- [TCP ports for GitLab services are already taken](common_installation_problems/README.md#tcp-ports-for-gitlab-services-are-already-taken).
- [Git SSH access stops working on SELinux-enabled systems](common_installation_problems/README.md#selinux-enabled-systems).
- [PostgreSQL error `FATAL:  could not create shared memory segment: Cannot allocate memory`](common_installation_problems/README.md#postgresql-error-fatal--could-not-create-shared-memory-segment-cannot-allocate-memory).
- [Reconfigure complains about the GLIBC version](common_installation_problems/README.md#reconfigure-complains-about-the-glibc-version).
- [Reconfigure fails to create the Git user](common_installation_problems/README.md#reconfigure-fails-to-create-the-git-user).
- [Failed to modify kernel parameters with sysctl](common_installation_problems/README.md#failed-to-modify-kernel-parameters-with-sysctl).
- [I am unable to install Omnibus GitLab without root access](common_installation_problems/README.md#i-am-unable-to-install-omnibus-gitlab-without-root-access).
- [`gitlab-rake assets:precompile` fails with `Permission denied`](common_installation_problems/README.md#gitlab-rake-assetsprecompile-fails-with-permission-denied).
- [`Short read or OOM loading DB` error](common_installation_problems/README.md#short-read-or-oom-loading-db-error).
- [`pg_dump: aborting because of server version mismatch`](settings/database.md#using-a-non-packaged-postgresql-database-management-server)
- [`Errno::ENOMEM: Cannot allocate memory` during backup or upgrade](common_installation_problems/README.md#errnoenomem-cannot-allocate-memory-during-backup-or-upgrade)
- [NGINX error: `could not build server_names_hash`](common_installation_problems/README.md#nginx-error-could-not-build-server_names_hash-you-should-increase-server_names_hash_bucket_size)
- [Reconfigure fails due to `'root' cannot chown` with NFS root_squash](common_installation_problems/README.md#reconfigure-fails-due-to-root-cannot-chown-with-nfs-root_squash)

## Omnibus GitLab developer documentation

See the [development documentation](development/README.md)
