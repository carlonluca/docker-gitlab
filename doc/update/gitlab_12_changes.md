# GitLab 12 specific changes

NOTE: **Note**
When upgrading to a new major version, remember to first [check for background migrations](https://docs.gitlab.com/ee/update/README.html#checking-for-background-migrations-before-upgrading).

## Prometheus 1.x Removal

Prometheus 1.x was deprecated in GitLab 11.4, and
Prometheus 2.8.1 was installed by default on new installations. Users updating
from older versions of GitLab could manually upgrade Prometheus data using the
[`gitlab-ctl prometheus-upgrade`](https://docs.gitlab.com/omnibus/update/gitlab_11_changes.html#114)
command provided. You can view current Prometheus version in use from the
instances Prometheus `/status` page.

With GitLab 12.0, support for Prometheus 1.x is completely removed, and as part
of the upgrade process, Prometheus binaries will be updated to version 2.8.1.
Existing data from Prometheus 1.x installation WILL NOT be migrated as part of
this automatic upgrade, and users who wish to retain that data should
[manually upgrade Prometheus version](https://docs.gitlab.com/omnibus/update/gitlab_11_changes.html#114)
before upgrading to GitLab 12.0

For users who use `/etc/gitlab/skip-auto-reconfigure` file to skip automatic
migrations and reconfigures during upgrade, Prometheus upgrade will also be
skipped. However, since the package no longer contains Prometheus 1.x binary,
the Prometheus service will be non-functional due to the mismatch between binary
version and data directory. Users will have to manually run `sudo gitlab-ctl
prometheus-upgrade` command to get Prometheus running again.

Please note that `gitlab-ctl prometheus-upgrade` command automatically
reconfigures your GitLab instance, and will cause database migrations to run.
So, if you are on an HA instance, run this command only as the last step, after
performing all database related actions.

## Removal of support for `/etc/gitlab/skip-auto-migrations` file

Before GitLab 10.6, the file `/etc/gitlab/skip-auto-migrations` was used to
prevent automatic reconfigure (and thus automatic database migrations) as part
of upgrade. This file had been deprecated in favor of `/etc/gitlab/skip-auto-reconfigure`
since GitLab 10.6, and in 12.0 the support is removed completely. Upgrade
process will no longer take `skip-auto-migrations` file into consideration.

## Deprecation of TLS v1.1

With the release of GitLab 12, TLS v1.1 has been fully deprecated.
This mitigates numerous issues including, but not limited to,
Heartbleed and makes GitLab compliant out of the box with the PCI
DSS 3.1 standard.

[Learn more about why TLS v1.1 is being deprecated in our blog.](https://about.gitlab.com/blog/2018/10/15/gitlab-to-deprecate-older-tls/)

## Upgrade to Postgres 10

CAUTION: **Caution:**
If you are running a Geo installation using PostgreSQL 9.6.x, please upgrade to GitLab 12.4 or newer. Older versions were affected [by an issue](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/4692) that could cause automatic upgrades of the PostgreSQL database to fail on the secondary. This issue is now fixed.

Postgres will automatically be upgraded to 10.x unless specifically opted
out during the upgrade. To opt out you must execute the following before
performing the upgrade of GitLab.

```bash
sudo touch /etc/gitlab/disable-postgresql-upgrade
```

Further details and procedures for upgrading a GitLab HA cluster can be
found in the [Database Settings notes](../settings/database.md#upgrade-packaged-postgresql-server).

### 12.1

#### Monitoring related node attributes moved to be under `monitoring` key

If you were using monitoring related node attributes like
`node['gitlab']['prometheus']` or `node['gitlab']['alertmanager']` in your
`gitlab.rb` file for configuring other settings, they are now under `monitoring`
key and should be renamed. The replacements are as follows

```
# Existing usage in gitlab.rb => Replacement

* node['gitlab']['prometheus'] => node['monitoring']['prometheus']
* node['gitlab']['alertmanager'] => node['monitoring']['alertmanager']
* node['gitlab']['redis-exporter'] => node['monitoring']['redis-exporter']
* node['gitlab']['node-exporter'] => node['monitoring']['node-exporter']
* node['gitlab']['postgres-exporter'] => node['monitoring']['postgres-exporter']
* node['gitlab']['gitlab-monitor'] => node['monitoring']['gitlab-monitor']
* node['gitlab']['grafana'] => node['monitoring']['grafana']
```

Also, it is recommended to use the actual values in `gitlab.rb` instead of
referring node values to avoid breakage when these attributes are moved in the
backend.

### 12.2

The default formula for calculating the number of Unicorn worker processes has been updated to increase the number of workers by 50% per CPU. This will increase the CPU and memory utilization slightly. This has been done to improve performance by reducing the amount of request queuing.

### 12.3

1. To prevent confusion with the broader GitLab Monitor feature set, the
   GitLab Monitor tool has been renamed to GitLab Exporter. As a result, usage
   of `gitlab_monitor[*]` keys in `gitlab.rb` file has been deprecated in favor
   of `gitlab_exporter[*]` ones.

   The deprecated settings will be removed in GitLab 13.0. They will continue to
   work till then, but warnings will be displayed at the end of reconfigure run.
   Since upgrades to 13.0 will be prevented if removed settings are found in
   `gitlab.rb`, users who are currently using those settings are advised to
   switch to `gitlab_exporter[*]` ones at the earliest.
