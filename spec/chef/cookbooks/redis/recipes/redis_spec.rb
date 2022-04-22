require 'chef_helper'

RSpec.describe 'redis' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(redis_service runit_service)).converge('gitlab::default') }
  let(:redis_conf) { '/var/opt/gitlab/redis/redis.conf' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'by default' do
    let(:gitlab_redis_cli_rc) do
      <<-EOF
redis_dir='/var/opt/gitlab/redis'
redis_host='127.0.0.1'
redis_port='0'
redis_socket='/var/opt/gitlab/redis/redis.socket'
      EOF
    end

    it 'enables the redis service' do
      expect(chef_run).to create_redis_service('redis')
    end

    it 'creates redis config with default values' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).to match(/client-output-buffer-limit normal 0 0 0/)
          expect(content).to match(/client-output-buffer-limit replica 256mb 64mb 60/)
          expect(content).to match(/client-output-buffer-limit pubsub 32mb 8mb 60/)
          expect(content).to match(/^hz 10/)
          expect(content).to match(/^save 900 1/)
          expect(content).to match(/^save 300 10/)
          expect(content).to match(/^save 60 10000/)
          expect(content).to match(/^maxmemory 0/)
          expect(content).to match(/^maxmemory-policy noeviction/)
          expect(content).to match(/^maxmemory-samples 5/)
          expect(content).to match(/^tcp-backlog 511/)
          expect(content).to match(/^rename-command KEYS ""$/)
          expect(content).to match(/^lazyfree-lazy-eviction no$/)
          expect(content).to match(/^lazyfree-lazy-expire no$/)
          expect(content).to match(/^io-threads 1$/)
          expect(content).to match(/^io-threads-do-reads no$/)
          expect(content).to match(/^stop-writes-on-bgsave-error yes$/)
          expect(content).not_to match(/^replicaof/)
          expect(content).not_to match(/^tls-/)
        }
    end

    it 'creates redis user and group' do
      expect(chef_run).to create_account('user and group for redis').with(username: 'gitlab-redis', groupname: 'gitlab-redis')
    end

    it_behaves_like 'enabled runit service', 'redis', 'root', 'root'

    it 'creates gitlab-redis-cli-rc' do
      expect(chef_run).to render_file('/opt/gitlab/etc/gitlab-redis-cli-rc')
        .with_content(gitlab_redis_cli_rc)
    end

    describe 'pending restart check' do
      context 'when running version is same as installed version' do
        before do
          allow_any_instance_of(RedisHelper).to receive(:running_version).and_return('3.2.12')
          allow_any_instance_of(RedisHelper).to receive(:installed_version).and_return('3.2.12')
        end

        it 'does not raise a warning' do
          expect(chef_run).not_to run_ruby_block('warn pending redis restart')
        end
      end

      context 'when running version is different than installed version' do
        before do
          allow_any_instance_of(RedisHelper).to receive(:running_version).and_return('3.2.12')
          allow_any_instance_of(RedisHelper).to receive(:installed_version).and_return('5.0.9')
        end

        it 'raises a warning' do
          expect(chef_run).to run_ruby_block('warn pending redis restart')
        end
      end
    end
  end

  context 'with user specified values' do
    before do
      stub_gitlab_rb(
        redis: {
          client_output_buffer_limit_normal: "5 5 5",
          client_output_buffer_limit_replica: "512mb 128mb 120",
          client_output_buffer_limit_pubsub: "64mb 16mb 120",
          save: ["10 15000"],
          maxmemory: "32gb",
          maxmemory_policy: "allkeys-url",
          maxmemory_samples: 10,
          tcp_backlog: 1024,
          hz: 100,
          username: 'foo',
          group: 'bar',
          rename_commands: {
            "FAKE_COMMAND" => "RENAMED_FAKE_COMMAND",
            "DISABLED_FAKE_COMMAND" => ""
          }
        }
      )
    end

    it 'creates redis config with custom values' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/client-output-buffer-limit normal 5 5 5/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/client-output-buffer-limit replica 512mb 128mb 120/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/client-output-buffer-limit pubsub 64mb 16mb 120/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^save 10 15000/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^maxmemory 32gb/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^maxmemory-policy allkeys-url/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^maxmemory-samples 10/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^tcp-backlog 1024/)
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^hz 100/)
    end

    it 'does not include the default renamed keys in redis.conf' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).not_to match(/^rename-command KEYS ""$/)
          expect(content).to match(/^rename-command FAKE_COMMAND "RENAMED_FAKE_COMMAND"$/)
          expect(content).to match(/^rename-command DISABLED_FAKE_COMMAND ""$/)
        }
    end

    it 'creates redis user and group' do
      expect(chef_run).to create_account('user and group for redis').with(username: 'foo', groupname: 'bar')
    end

    it_behaves_like 'enabled runit service', 'redis', 'root', 'root'
  end

  context 'with snapshotting disabled' do
    before do
      stub_gitlab_rb(
        redis: {
          save: []
        }
      )
    end
    it 'creates redis config without save setting' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
      expect(chef_run).not_to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^save/)
    end
  end

  context 'with snapshotting cleared' do
    before do
      stub_gitlab_rb(
        redis: {
          save: [""]
        }
      )
    end
    it 'creates redis config without save setting' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^save ""/)
    end
  end

  context 'with a replica configured' do
    let(:redis_host) { '1.2.3.4' }
    let(:redis_port) { 6370 }
    let(:master_ip) { '10.0.0.0' }
    let(:master_port) { 6371 }

    let(:gitlab_redis_cli_rc) do
      <<-EOF
redis_dir='/var/opt/gitlab/redis'
redis_host='1.2.3.4'
redis_port='6370'
redis_socket=''
      EOF
    end

    before do
      stub_gitlab_rb(
        redis: {
          bind: redis_host,
          port: redis_port,
          master_ip: master_ip,
          master_port: master_port,
          master_password: 'password',
          master: false
        }
      )
    end

    it 'includes replicaof' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^replicaof #{master_ip} #{master_port}/)
    end

    it 'creates gitlab-redis-cli-rc' do
      expect(chef_run).to render_file('/opt/gitlab/etc/gitlab-redis-cli-rc')
        .with_content(gitlab_redis_cli_rc)
    end
  end

  context 'in HA mode with Sentinels' do
    let(:redis_host) { '1.2.3.4' }
    let(:redis_port) { 6370 }
    let(:master_ip) { '10.0.0.0' }
    let(:master_port) { 6371 }

    let(:gitlab_redis_cli_rc) do
      <<-EOF
redis_dir='/var/opt/gitlab/redis'
redis_host='1.2.3.4'
redis_port='6370'
redis_socket=''
      EOF
    end

    before do
      stub_gitlab_rb(
        redis: {
          bind: redis_host,
          port: redis_port,
          ha: true,
          master_ip: master_ip,
          master_port: master_port,
          master_password: 'password',
          master: false
        }
      )
    end

    it 'omits replicaof' do
      expect(chef_run).not_to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content(/^replicaof/)
    end

    it 'creates gitlab-redis-cli-rc' do
      expect(chef_run).to render_file('/opt/gitlab/etc/gitlab-redis-cli-rc')
        .with_content(gitlab_redis_cli_rc)
    end
  end

  context 'with rename_commands disabled' do
    before do
      stub_gitlab_rb(
        redis: {
          rename_commands: {}
        }
      )
    end

    it 'should not rename any commands' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).not_to match(/^rename-command/)
        }
    end
  end

  context 'with lazy eviction enabled' do
    before do
      stub_gitlab_rb(
        redis: {
          lazyfree_lazy_eviction: true
        }
      )
    end

    it 'creates redis config with lazyfree-lazy-eviction yes' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).to match(/^lazyfree-lazy-eviction yes$/)
          expect(content).to match(/^lazyfree-lazy-expire no$/)
        }
    end
  end

  context 'with lazy eviction enabled' do
    before do
      stub_gitlab_rb(
        redis: {
          io_threads: 4,
          io_threads_do_reads: true
        }
      )
    end

    it 'creates redis config with lazyfree-lazy-eviction yes' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).to match(/^io-threads 4$/)
          expect(content).to match(/^io-threads-do-reads yes$/)
        }
    end
  end

  context 'with stop writes on bgsave error disabled' do
    before do
      stub_gitlab_rb(
        redis: {
          stop_writes_on_bgsave_error: false
        }
      )
    end

    it 'creates redis config with stop-writes-on-bgsave-error no' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).to match(/^stop-writes-on-bgsave-error no$/)
        }
    end
  end

  context 'with tls settings specified' do
    before do
      stub_gitlab_rb(
        redis: {
          tls_port: 6380,
          tls_cert_file: '/etc/gitlab/ssl/redis.crt',
          tls_key_file: '/etc/gitlab/ssl/redis.key',
          tls_dh_params_file: '/etc/gitlab/ssl/redis-dhparams',
          tls_ca_cert_file: '/etc/gitlab/ssl/redis-ca.crt',
          tls_ca_cert_dir: '/opt/gitlab/embedded/ssl/certs',
          tls_auth_clients: 'no',
          tls_replication: 'yes',
          tls_cluster: 'yes',
          tls_protocols: 'TLSv1.2 TLSv1.3',
          tls_ciphers: 'DEFAULT:!MEDIUM',
          tls_ciphersuites: 'TLS_CHACHA20_POLY1305_SHA256',
          tls_prefer_server_ciphers: 'yes',
          tls_session_caching: 'no',
          tls_session_cache_size: 10000,
          tls_session_cache_timeout: 120
        }
      )
    end

    it 'renders redis config with tls settings' do
      expect(chef_run).to render_file('/var/opt/gitlab/redis/redis.conf')
        .with_content { |content|
          expect(content).to match(%r{^tls-port 6380$})
          expect(content).to match(%r{^tls-cert-file /etc/gitlab/ssl/redis.crt$})
          expect(content).to match(%r{^tls-key-file /etc/gitlab/ssl/redis.key$})
          expect(content).to match(%r{^tls-dh-params-file /etc/gitlab/ssl/redis-dhparams$})
          expect(content).to match(%r{^tls-ca-cert-file /etc/gitlab/ssl/redis-ca.crt$})
          expect(content).to match(%r{^tls-ca-cert-dir /opt/gitlab/embedded/ssl/certs$})
          expect(content).to match(%r{^tls-auth-clients no$})
          expect(content).to match(%r{^tls-replication yes$})
          expect(content).to match(%r{^tls-cluster yes$})
          expect(content).to match(%r{^tls-protocols "TLSv1.2 TLSv1.3"$})
          expect(content).to match(%r{^tls-ciphers DEFAULT:!MEDIUM$})
          expect(content).to match(%r{^tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256$})
          expect(content).to match(%r{^tls-prefer-server-ciphers yes$})
          expect(content).to match(%r{^tls-session-caching no$})
          expect(content).to match(%r{^tls-session-cache-size 10000$})
          expect(content).to match(%r{^tls-session-cache-timeout 120$})
        }
    end
  end

  context 'with redis disabled' do
    before do
      stub_gitlab_rb(redis: { enable: false })
    end

    it_behaves_like 'disabled runit service', 'redis', 'root', 'root'
  end
end
