####
# GitLab Kubernetes Agent Server
####
default['gitlab_kas']['enable'] = false
default['gitlab_kas']['agent_configuration_poll_period'] = 20
default['gitlab_kas']['agent_gitops_poll_period'] = 20
default['gitlab_kas']['agent_gitops_project_info_cache_ttl'] = 300
default['gitlab_kas']['agent_gitops_project_info_cache_error_ttl'] = 60
default['gitlab_kas']['agent_info_cache_ttl'] = 300
default['gitlab_kas']['agent_info_cache_error_ttl'] = 60
default['gitlab_kas']['gitlab_address'] = ''
default['gitlab_kas']['gitlab_external_url'] = nil
default['gitlab_kas']['api_secret_key'] = nil
default['gitlab_kas']['listen_address'] = 'localhost:8150'
default['gitlab_kas']['listen_network'] = 'tcp'
default['gitlab_kas']['listen_websocket'] = true
default['gitlab_kas']['certificate_file'] = nil
default['gitlab_kas']['key_file'] = nil
default['gitlab_kas']['observability_listen_address'] = 'localhost:8151'
default['gitlab_kas']['observability_listen_network'] = 'tcp'
default['gitlab_kas']['internal_api_listen_address'] = 'localhost:8153'
default['gitlab_kas']['internal_api_listen_network'] = 'tcp'
default['gitlab_kas']['internal_api_certificate_file'] = nil
default['gitlab_kas']['internal_api_key_file'] = nil
default['gitlab_kas']['kubernetes_api_listen_address'] = 'localhost:8154'
default['gitlab_kas']['kubernetes_api_certificate_file'] = nil
default['gitlab_kas']['kubernetes_api_key_file'] = nil
default['gitlab_kas']['private_api_secret_key'] = nil
default['gitlab_kas']['private_api_listen_address'] = 'localhost:8155'
default['gitlab_kas']['private_api_listen_network'] = 'tcp'
default['gitlab_kas']['private_api_certificate_file'] = nil
default['gitlab_kas']['private_api_key_file'] = nil
default['gitlab_kas']['metrics_usage_reporting_period'] = 60
default['gitlab_kas']['sentry_dsn'] = nil
default['gitlab_kas']['sentry_environment'] = nil
default['gitlab_kas']['log_level'] = 'info'
default['gitlab_kas']['dir'] = '/var/opt/gitlab/gitlab-kas'
default['gitlab_kas']['log_directory'] = '/var/log/gitlab/gitlab-kas'
default['gitlab_kas']['env_directory'] = '/opt/gitlab/etc/gitlab-kas/env'
default['gitlab_kas']['env'] = {
  'SSL_CERT_DIR' => "#{node['package']['install-dir']}/embedded/ssl/certs/",
  'OWN_PRIVATE_API_URL' => 'grpc://localhost:8155'
}

default['gitlab-kas'] = Gitlab::Deprecations::NodeAttribute.new(proc { node['gitlab_kas'].to_h }, "node['gitlab-kas']", "node['gitlab_kas']")
