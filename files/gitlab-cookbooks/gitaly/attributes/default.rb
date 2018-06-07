default['gitaly']['enable'] = false
default['gitaly']['ha'] = false
default['gitaly']['dir'] = "/var/opt/gitlab/gitaly"
default['gitaly']['log_directory'] = "/var/log/gitlab/gitaly"
default['gitaly']['env_directory'] = "/opt/gitlab/etc/gitaly"
default['gitaly']['bin_path'] = "/opt/gitlab/embedded/bin/gitaly"
default['gitaly']['socket_path'] = "#{node['gitaly']['dir']}/gitaly.socket"
default['gitaly']['listen_addr'] = nil
default['gitaly']['prometheus_listen_addr'] = "localhost:9236"
default['gitaly']['logging_format'] = nil
default['gitaly']['logging_sentry_dsn'] = nil
default['gitaly']['logging_ruby_sentry_dsn'] = nil
default['gitaly']['prometheus_grpc_latency_buckets'] = nil
default['gitaly']['storage'] = []
default['gitaly']['auth_token'] = nil
default['gitaly']['auth_transitioning'] = false
default['gitaly']['ruby_max_rss'] = nil
default['gitaly']['ruby_graceful_restart_timeout'] = nil
default['gitaly']['ruby_restart_delay'] = nil
default['gitaly']['ruby_num_workers'] = nil
default['gitaly']['concurrency'] = nil
