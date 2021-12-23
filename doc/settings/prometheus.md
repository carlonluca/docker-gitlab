---
stage: Enablement
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
---

# Prometheus Settings **(FREE SELF)**

## Remote read/write

Prometheus supports reading and writing to remote services.

To configure a remote read or write service, you can include the following in `gitlab.rb`.

```ruby
prometheus['remote_write'] = [
  {
    url: 'https://some-remote-write-service.example.com',
    basic_auth: {
      password: 'remote write secret password'
    }
  }
]
prometheus['remote_read'] = [
  {
    url: 'https://some-remote-write-service.example.com'
  }
]
```

For more documentation on the options available, see the [remote write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Cremote_write%3E) and [remote read](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Cremote_read%3E) sections of the official documentation.

## Rules files

Prometheus allows for [recording](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) and [alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) rules.

Omnibus includes some [default rules files](https://gitlab.com/gitlab-org/omnibus-gitlab/tree/master/files/gitlab-cookbooks/monitoring/templates/rules)
that are stored in `/var/opt/gitlab/prometheus/rules/`.

To override the default rules, you can change the default list in `gitlab.rb.`.

No rules:

```ruby
prometheus['rules_files'] = []
```

Custom list:

```ruby
prometheus['rules_files'] = ['/path/to/rules/*.rules', '/path/to/single/file.rules']
```

## External labels

To set [external labels](https://prometheus.io/docs/prometheus/latest/configuration/configuration/):

```ruby
prometheus['external_labels'] = {
    'region' => 'us-west-2',
    'source' => 'omnibus',
}
```

No external labels are set by default.

## node_exporter

The node_exporter provides system level metrics.

Additional metrics collectors are enabled by default. For example, `mountstats` is used to collect metrics about NFS mounts.

To disable the `mountstats` collector, adjust `gitlab.rb` with the following setting and run `gitlab-ctl reconfigure`:

```ruby
node_exporter['flags'] = {
  'collector.mountstats' => false,
}
```

For more information on available collectors, see the [upstream documentation](https://github.com/prometheus/node_exporter#collectors).

## Grafana dashboards

[Grafana](https://grafana.com) is a powerful dashboard software for presenting
Prometheus metrics data. Omnibus GitLab >= 11.9 includes an embedded copy.

See [the embedded Grafana documentation](grafana.md) for more information.

## Alertmanager global options

You can set [global options](https://prometheus.io/docs/alerting/latest/configuration/)
for the [Alertmanager](https://prometheus.io/docs/alerting/latest/configuration/).

For example, the following `gitlab.rb` configuration overrides the hostname Alertmanager
uses to identify itself to the SMTP server:

```ruby
alertmanager['global'] = {
  'smtp_hello' => 'example.org'
}
```
