default['gitaly']['enable'] = false
default['gitaly']['ha'] = false
default['gitaly']['dir'] = "/var/opt/gitlab/gitaly"
default['gitaly']['log_directory'] = "/var/log/gitlab/gitaly"
default['gitaly']['env_directory'] = "/opt/gitlab/etc/gitaly/env"
default['gitaly']['graceful_restart_timeout'] = nil
# default['gitaly']['env'] is set in ../recipes/enable.rb
default['gitaly']['bin_path'] = "/opt/gitlab/embedded/bin/gitaly"
default['gitaly']['socket_path'] = "#{node['gitaly']['dir']}/gitaly.socket"
default['gitaly']['listen_addr'] = nil
default['gitaly']['tls_listen_addr'] = nil
default['gitaly']['certificate_path'] = nil
default['gitaly']['key_path'] = nil
default['gitaly']['prometheus_listen_addr'] = "localhost:9236"
default['gitaly']['logging_level'] = nil
default['gitaly']['logging_format'] = "json"
default['gitaly']['logging_sentry_dsn'] = nil
default['gitaly']['logging_ruby_sentry_dsn'] = nil
default['gitaly']['logging_sentry_environment'] = nil
default['gitaly']['prometheus_grpc_latency_buckets'] = nil
default['gitaly']['storage'] = []
default['gitaly']['auth_token'] = nil
default['gitaly']['auth_transitioning'] = false
default['gitaly']['git_catfile_cache_size'] = nil
default['gitaly']['ruby_max_rss'] = nil
default['gitaly']['ruby_graceful_restart_timeout'] = nil
default['gitaly']['ruby_restart_delay'] = nil
default['gitaly']['ruby_num_workers'] = nil
default['gitaly']['concurrency'] = nil
