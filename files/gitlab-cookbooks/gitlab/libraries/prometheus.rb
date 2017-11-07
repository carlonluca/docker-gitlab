#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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

require_relative 'postgresql.rb'
require_relative 'redis.rb'

require 'yaml'
require 'json'

module Prometheus
  class << self
    def services
      Services.find_by_group('prometheus').map { |name, _| name.tr('_', '-') }
    end

    def parse_variables
      parse_exporter_enabled
      parse_monitoring_enabled
      parse_scrape_configs
      parse_flags
    end

    def parse_monitoring_enabled
      # Disabled monitoring if it has been explicitly set to false
      Services.disable_group('prometheus', include_system: true) if Gitlab['prometheus_monitoring']['enable'] == false
    end

    def parse_exporter_enabled
      # Disable exporters by default if their service is not managed on this node
      Services.set_enable('postgres_exporter', Postgresql.postgresql_managed?) if Gitlab['postgres_exporter']['enable'].nil?
      Services.set_enable('redis_exporter', Redis.redis_managed?) if Gitlab['redis_exporter']['enable'].nil?
    end

    def parse_flags
      parse_prometheus_flags
      parse_node_exporter_flags
      parse_postgres_exporter_flags
      parse_redis_exporter_flags
    end

    def parse_prometheus_flags
      default_config = Gitlab['node']['gitlab']['prometheus'].to_hash
      user_config = Gitlab['prometheus']

      home_directory = user_config['home'] || default_config['home']
      listen_address = user_config['listen_address'] || default_config['listen_address']
      chunk_encoding_version = user_config['chunk_encoding_version'] || default_config['chunk_encoding_version']
      target_heap_size = user_config['target_heap_size'] || default_config['target_heap_size']
      default_config['flags'] = {
        'web.listen-address' => listen_address,
        'storage.local.path' => File.join(home_directory, 'data'),
        'storage.local.chunk-encoding-version' => chunk_encoding_version.to_s,
        'storage.local.target-heap-size' => target_heap_size.to_s,
        'config.file' => File.join(home_directory, 'prometheus.yml')
      }

      default_config['flags'].merge!(user_config['flags']) if user_config.key?('flags')

      Gitlab['prometheus']['flags'] = default_config['flags']
    end

    def parse_node_exporter_flags
      default_config = Gitlab['node']['gitlab']['node-exporter'].to_hash
      user_config = Gitlab['node_exporter']

      home_directory = user_config['home'] || default_config['home']
      listen_address = user_config['listen_address'] || default_config['listen_address']
      default_config['flags'] = {
        'web.listen-address' => listen_address,
        'collector.textfile.directory' => File.join(home_directory, 'textfile_collector')
      }

      default_config['flags'].merge!(user_config['flags']) if user_config.key?('flags')

      Gitlab['node_exporter']['flags'] = default_config['flags']
    end

    def parse_redis_exporter_flags
      default_config = Gitlab['node']['gitlab']['redis-exporter'].to_hash
      user_config = Gitlab['redis_exporter']

      listen_address = user_config['listen_address'] || default_config['listen_address']
      default_config['flags'] = {
        'web.listen-address' => listen_address,
        'redis.addr' => "unix://#{Gitlab['node']['gitlab']['gitlab-rails']['redis_socket']}"
      }

      default_config['flags'].merge!(user_config['flags']) if user_config.key?('flags')

      Gitlab['redis_exporter']['flags'] = default_config['flags']
    end

    def parse_postgres_exporter_flags
      default_config = Gitlab['node']['gitlab']['postgres-exporter'].to_hash
      user_config = Gitlab['postgres_exporter']

      home_directory = user_config['home'] || default_config['home']
      listen_address = user_config['listen_address'] || default_config['listen_address']
      default_config['flags'] = {
        'web.listen-address' => listen_address,
        'extend.query-path' => File.join(home_directory, 'queries.yaml'),
      }

      default_config['flags'].merge!(user_config['flags']) if user_config.key?('flags')

      Gitlab['postgres_exporter']['flags'] = default_config['flags']
    end

    def parse_scrape_configs
      # Don't parse if prometheus is explicitly disabled
      return unless Services.enabled?('prometheus')
      gitlab_monitor_scrape_configs
      unicorn_scrape_configs
      exporter_scrape_config('node')
      exporter_scrape_config('postgres')
      exporter_scrape_config('redis')
      prometheus_scrape_configs
    end

    def gitlab_monitor_scrape_configs
      # Don't parse if gitlab_monitor is explicitly disabled
      return unless Services.enabled?('gitlab_monitor')

      default_config = Gitlab['node']['gitlab']['gitlab-monitor'].to_hash
      user_config = Gitlab['gitlab_monitor']

      listen_address = user_config['listen_address'] || default_config['listen_address']
      listen_port = user_config['listen_port'] || default_config['listen_port']
      prometheus_target = [ listen_address, listen_port ].join(':')

      # Include gitlab-monitor defaults scrape config.
      database =  {
                    'job_name' => 'gitlab_monitor_database',
                    'metrics_path' => '/database',
                    'static_configs' => [
                      'targets' => [prometheus_target],
                    ]
                  }
      sidekiq = {
                  'job_name' => 'gitlab_monitor_sidekiq',
                  'metrics_path' => '/sidekiq',
                  'static_configs' => [
                    'targets' => [prometheus_target],
                  ]
                }
      process = {
                  'job_name' => 'gitlab_monitor_process',
                  'metrics_path' => '/process',
                  'static_configs' => [
                    'targets' => [prometheus_target],
                  ]
                }

      default_scrape_configs = [] << database << sidekiq << process << Gitlab['prometheus']['scrape_configs']
      Gitlab['prometheus']['scrape_configs'] = default_scrape_configs.compact.flatten
    end

    def unicorn_scrape_configs
      # Don't parse if unicorn is explicitly disabled
      return unless Services.enabled?('unicorn')

      default_config = Gitlab['node']['gitlab']['unicorn'].to_hash
      user_config = Gitlab['unicorn']

      listen_address = user_config['listen'] || default_config['listen']
      listen_port = user_config['port'] || default_config['port']
      prometheus_target = [ listen_address, listen_port ].join(':')

      scrape_config = {
                        'job_name' => 'gitlab-unicorn',
                        'metrics_path' => '/-/metrics',
                        'static_configs' => [
                          'targets' => [prometheus_target],
                        ]
                      }

      default_scrape_configs = [] << scrape_config << Gitlab['prometheus']['scrape_configs']
      Gitlab['prometheus']['scrape_configs'] = default_scrape_configs.compact.flatten
    end

    def exporter_scrape_config(exporter)
      # Don't parse if exporter is explicitly disabled
      return unless Services.enabled?("#{exporter}_exporter")

      default_config = Gitlab['node']['gitlab']["#{exporter}-exporter"].to_hash
      user_config = Gitlab["#{exporter}_exporter"]

      listen_address = user_config['listen_address'] || default_config['listen_address']

      default_config = {
                          'job_name' => exporter,
                          'static_configs' => [
                            'targets' => [listen_address],
                          ],
                        }

      default_scrape_configs = [] << default_config << Gitlab['prometheus']['scrape_configs']
      Gitlab['prometheus']['scrape_configs'] = default_scrape_configs.compact.flatten
    end

    def prometheus_scrape_configs
      default_config = Gitlab['node']['gitlab']['prometheus'].to_hash
      user_config = Gitlab['prometheus']

      listen_address = user_config['listen_address'] || default_config['listen_address']

      prometheus = {
                'job_name' => 'prometheus',
                'static_configs' => [
                  'targets' => [listen_address],
                ],
              }

      k8s_cadvisor = {
          'job_name' => 'kubernetes-cadvisor',
          'scheme' => 'https',
          'tls_config' => {
            'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            'insecure_skip_verify' => true,
          },
          'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
          'kubernetes_sd_configs' => [
            {
              'role' => 'node',
              'api_server' => 'https://kubernetes.default.svc:443',
              'tls_config' => {
                'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
              },
              'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
            },
          ],
          'relabel_configs' => [
            {
              'action' => 'labelmap',
              'regex' => '__meta_kubernetes_node_label_(.+)',
            },
            {
              'target_label' => '__address__',
              'replacement' => 'kubernetes.default.svc:443',
            },
            {
              'source_labels' => ['__meta_kubernetes_node_name'],
              'regex' => '(.+)',
              'target_label' => '__metrics_path__',
              'replacement' => '/api/v1/nodes/${1}/proxy/metrics/cadvisor',
            },
          ],
          'metric_relabel_configs' => [
            {
              'source_labels' => ['pod_name'],
              'target_label' => 'environment',
              'regex' => '(.+)-.+-.+',
            },
          ],
        }

      k8s_nodes = {
          'job_name' => 'kubernetes-nodes',
          'scheme' => 'https',
          'tls_config' => {
            'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            'insecure_skip_verify' => true,
          },
          'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
          'kubernetes_sd_configs' => [
            {
              'role' => 'node',
              'api_server' => 'https://kubernetes.default.svc:443',
              'tls_config' => {
                'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
              },
              'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
            },
          ],
          'relabel_configs' => [
            {
              'action' => 'labelmap',
              'regex' => '__meta_kubernetes_node_label_(.+)',
            },
            {
              'target_label' => '__address__',
              'replacement' => 'kubernetes.default.svc:443',
            },
            {
              'source_labels' => ['__meta_kubernetes_node_name'],
              'regex' => '(.+)',
              'target_label' => '__metrics_path__',
              'replacement' => '/api/v1/nodes/${1}/proxy/metrics',
            },
          ],
          'metric_relabel_configs' => [
            {
              'source_labels' => ['pod_name'],
              'target_label' => 'environment',
              'regex' => '(.+)-.+-.+',
            },
          ],
        }

      k8s_pods = {
          'job_name' => 'kubernetes-pods',
          'tls_config' => {
            'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            'insecure_skip_verify' => true,
          },
          'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
          'kubernetes_sd_configs' => [
            {
              'role' => 'pod',
              'api_server' => 'https://kubernetes.default.svc:443',
              'tls_config' => {
                'ca_file' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
              },
              'bearer_token_file' => '/var/run/secrets/kubernetes.io/serviceaccount/token',
            },
          ],
          'relabel_configs' => [
            {
              'source_labels' => ['__meta_kubernetes_pod_annotation_prometheus_io_scrape'],
              'action' => 'keep',
              'regex' => 'true',
            },
            {
              'source_labels' => ['__meta_kubernetes_pod_annotation_prometheus_io_path'],
              'action' => 'replace',
              'target_label' => '__metrics_path__',
              'regex' => '(.+)',
            },
            {
              'source_labels' => ['__address__', '__meta_kubernetes_pod_annotation_prometheus_io_port'],
              'action' => 'replace',
              'regex' => '([^:]+)(?::[0-9]+)?;([0-9]+)',
              'replacement' => '$1:$2',
              'target_label' => '__address__',
            },
            {
              'action' => 'labelmap',
              'regex' => '__meta_kubernetes_pod_label_(.+)',
            },
            {
              'source_labels' => ['__meta_kubernetes_namespace'],
              'action' => 'replace',
              'target_label' => 'kubernetes_namespace',
            },
            {
              'source_labels' => ['__meta_kubernetes_pod_name'],
              'action' => 'replace',
              'target_label' => 'kubernetes_pod_name',
            },
          ],
        }

      default_scrape_configs = [] << prometheus << Gitlab['prometheus']['scrape_configs']
      default_scrape_configs = default_scrape_configs << k8s_cadvisor << k8s_nodes << k8s_pods unless Gitlab['prometheus']['monitor_kubernetes'] == false
      Gitlab['prometheus']['scrape_configs'] = default_scrape_configs.compact.flatten
    end

    # This is a hack to avoid chef's to_yaml issues.
    def hash_to_yaml(hash)
      mutable_hash = JSON.parse(hash.dup.to_json)
      mutable_hash.to_yaml
    end
  end
end
