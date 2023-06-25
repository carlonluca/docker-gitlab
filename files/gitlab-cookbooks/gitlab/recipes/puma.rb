#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# Copyright:: Copyright (c) 2018 GitLab.com
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
account_helper = AccountHelper.new(node)
omnibus_helper = OmnibusHelper.new(node)
logfiles_helper = LogfilesHelper.new(node)
logging_settings = logfiles_helper.logging_settings('puma')

metrics_dir = File.join(node['gitlab']['runtime_dir'].to_s, 'gitlab/puma') unless node['gitlab']['runtime_dir'].nil?

svc = 'puma'
user = account_helper.gitlab_user
rails_home = node['gitlab']['gitlab_rails']['dir']
puma_listen_socket = node['gitlab'][svc]['socket']
puma_pidfile = node['gitlab'][svc]['pidfile']
puma_state_path = node['gitlab'][svc]['state_path']
puma_socket_dir = File.dirname(puma_listen_socket) if puma_listen_socket && !puma_listen_socket.empty?
puma_listen_host = node['gitlab'][svc]['listen']

# This works around not being able to disable `listen` with `nil` to defaults.
puma_listen_tcp = [puma_listen_host, node['gitlab'][svc]['port']].join(':') if puma_listen_host && !puma_listen_host.empty?

puma_listen_ssl_host = node['gitlab'][svc]['ssl_listen']
puma_ssl_port = node['gitlab'][svc]['ssl_port']
puma_ssl_cert = node['gitlab'][svc]['ssl_certificate']
puma_ssl_key = node['gitlab'][svc]['ssl_certificate_key']
puma_ssl_key_password_command = node['gitlab'][svc]['ssl_key_password_command']
puma_ssl_client_cert = node['gitlab'][svc]['ssl_client_certificate']
puma_ssl_cipher_filter = node['gitlab'][svc]['ssl_cipher_filter']
puma_ssl_verify_mode = node['gitlab'][svc]['ssl_verify_mode']

puma_etc_dir = File.join(rails_home, "etc")
puma_working_dir = File.join(rails_home, "working")
puma_rb = File.join(puma_etc_dir, "puma.rb")

node.default['gitlab'][svc]['worker_processes'] = Puma.workers unless node['gitlab'][svc]['worker_processes']

actioncable_worker_pool_size = node['gitlab']['actioncable']['worker_pool_size']

directory File.dirname(puma_pidfile) do
  owner user
  mode '0700'
  recursive true
end

# Create log_directory
directory logging_settings[:log_directory] do
  owner logging_settings[:log_directory_owner]
  mode logging_settings[:log_directory_mode]
  if log_group = logging_settings[:log_directory_group]
    group log_group
  end
  recursive true
end

if puma_socket_dir
  directory puma_socket_dir do
    owner user
    group AccountHelper.new(node).web_server_group
    mode '0750'
    recursive true
  end
end

puma_config puma_rb do
  environment node['gitlab']['gitlab_rails']['environment']
  listen_socket puma_listen_socket
  listen_tcp puma_listen_tcp
  ssl_listen_host puma_listen_ssl_host
  ssl_port puma_ssl_port
  ssl_certificate puma_ssl_cert
  ssl_certificate_key puma_ssl_key
  ssl_cipher_filter puma_ssl_cipher_filter
  ssl_client_certificate puma_ssl_client_cert
  ssl_key_password_command puma_ssl_key_password_command
  ssl_verify_mode puma_ssl_verify_mode
  worker_timeout node['gitlab'][svc]['worker_timeout']
  per_worker_max_memory_mb node['gitlab'][svc]['per_worker_max_memory_mb']
  working_directory puma_working_dir
  worker_processes node['gitlab'][svc]['worker_processes']
  min_threads node['gitlab'][svc]['min_threads']
  max_threads node['gitlab'][svc]['max_threads']
  stderr_path File.join(logging_settings[:log_directory], "puma_stderr.log")
  stdout_path File.join(logging_settings[:log_directory], "puma_stdout.log")
  pid puma_pidfile
  state_path puma_state_path
  owner "root"
  group "root"
  mode "0644"
  action :create
  dependent_services omnibus_helper.should_notify?(svc) ? ["runit_service[#{svc}]"] : []
end

runit_service svc do
  start_down node['gitlab'][svc]['ha']
  # sv-control-h handles a HUP signal and issues a SIGINT, SIGTERM
  # to the master puma process to perform a graceful restart
  restart_command_name 'hup'
  template_name 'puma'
  control %w[t h]
  options({
    service: svc,
    user: account_helper.gitlab_user,
    groupname: account_helper.gitlab_group,
    puma_rb: puma_rb,
    log_directory: logging_settings[:log_directory],
    log_user: logging_settings[:runit_owner],
    log_group: logging_settings[:runit_group],
    actioncable_worker_pool_size: actioncable_worker_pool_size,
    metrics_dir: metrics_dir,
    clean_metrics_dir: false
  }.merge(params))
  log_options logging_settings[:options]
end

if node['gitlab']['bootstrap']['enable']
  execute "/opt/gitlab/bin/gitlab-ctl start #{svc}" do
    retries 20
  end
end

consul_service node['gitlab']['puma']['consul_service_name'] do
  id 'rails'
  action Prometheus.service_discovery_action
  ip_address node['gitlab']['puma']['listen']
  port node['gitlab']['puma']['port']
  reload_service false unless Services.enabled?('consul')
end

gitlab_sysctl "net.core.somaxconn" do
  value node['gitlab']['puma']['somaxconn']
end
