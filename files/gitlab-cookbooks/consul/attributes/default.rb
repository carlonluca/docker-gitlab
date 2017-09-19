default['consul']['enable'] = false
default['consul']['dir'] = '/var/opt/gitlab/consul'
default['consul']['user'] = 'gitlab-consul'
default['consul']['config_file'] = '/var/opt/gitlab/consul/config.json'
default['consul']['config_dir'] = '/var/opt/gitlab/consul/config.d'
default['consul']['data_dir'] = '/var/opt/gitlab/consul/data'
default['consul']['log_directory'] = '/var/log/gitlab/consul'
default['consul']['script_directory'] = '/var/opt/gitlab/consul/scripts'
default['consul']['configuration'] = {}

# Critical state of service:postgresql indicates a node is not a master
# It does not need to be logged. Health status should be checked from
# the consul cluster.
default['consul']['logging_filters'] = {
  postgresql_warning: "-*agent: Check 'service:postgresql' is now critical"
}
