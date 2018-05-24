require 'chef_helper'

describe 'gitaly' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(env_dir)).converge('gitlab::default') }
  let(:config_path) { '/var/opt/gitlab/gitaly/config.toml' }
  let(:gitaly_config) { chef_run.template(config_path) }
  let(:socket_path) { '/tmp/gitaly.socket' }
  let(:listen_addr) { 'localhost:7777' }
  let(:prometheus_listen_addr) { 'localhost:9000' }
  let(:logging_format) { 'json' }
  let(:logging_sentry_dsn) { 'https://my_key:my_secret@sentry.io/test_project' }
  let(:logging_ruby_sentry_dsn) { 'https://my_key:my_secret@sentry.io/test_project-ruby' }
  let(:prometheus_grpc_latency_buckets) do
    '[0.001, 0.005, 0.025, 0.1, 0.5, 1.0, 10.0, 30.0, 60.0, 300.0, 1500.0]'
  end
  let(:auth_token) { '123secret456' }
  let(:auth_transitioning) { true }
  let(:ruby_max_rss) { 1000000 }
  let(:ruby_graceful_restart_timeout) { '30m' }
  let(:ruby_restart_delay) { '10m' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'by default' do
    it_behaves_like "enabled runit service", "gitaly", "root", "root"

    it 'creates expected directories with correct permissions' do
      expect(chef_run).to create_directory('/var/opt/gitlab/gitaly').with(user: 'git', mode: '0700')
      expect(chef_run).to create_directory('/var/log/gitlab/gitaly').with(user: 'git', mode: '0700')
      expect(chef_run).to create_directory('/opt/gitlab/etc/gitaly')
      expect(chef_run).to create_file('/opt/gitlab/etc/gitaly/PATH')
    end

    it 'creates a default VERSION file' do
      expect(chef_run).to create_file('/var/opt/gitlab/gitaly/VERSION').with(
        user: nil,
        group: nil
      )
    end

    it 'populates gitaly config.toml with defaults' do
      expect(chef_run).to render_file(config_path)
        .with_content("socket_path = '/var/opt/gitlab/gitaly/gitaly.socket'")
      expect(chef_run).to render_file(config_path)
        .with_content("bin_dir = '/opt/gitlab/embedded/bin'")
      expect(chef_run).not_to render_file(config_path)
        .with_content("listen_addr = '#{listen_addr}'")
      expect(chef_run).not_to render_file(config_path)
        .with_content("prometheus_listen_addr = '#{prometheus_listen_addr}'")
      expect(chef_run).not_to render_file(config_path)
        .with_content(%r{\[logging\]\s+format = '#{logging_format}'\s+sentry_dsn = '#{logging_sentry_dsn}'})
      expect(chef_run).not_to render_file(config_path)
        .with_content(%r{\[logging\]\s+format = '#{logging_format}'\s+ruby_sentry_dsn = '#{logging_ruby_sentry_dsn}'})
      expect(chef_run).not_to render_file(config_path)
        .with_content(%r{\[prometheus\]\s+grpc_latency_buckets = #{Regexp.escape(prometheus_grpc_latency_buckets)}})
      expect(chef_run).not_to render_file(config_path)
        .with_content(%r{\[auth\]\s+token = })
      expect(chef_run).not_to render_file(config_path)
        .with_content('transitioning =')
      expect(chef_run).not_to render_file(config_path)
        .with_content('max_rss =')
      expect(chef_run).not_to render_file(config_path)
        .with_content('graceful_restart_timeout =')
      expect(chef_run).not_to render_file(config_path)
        .with_content('restart_delay =')
    end

    it 'populates gitaly config.toml with default storages' do
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/var/opt/gitlab/git-data/repositories'})
    end
  end

  context 'with user settings' do
    before do
      stub_gitlab_rb(
        gitaly: {
          socket_path: socket_path,
          listen_addr: listen_addr,
          prometheus_listen_addr: prometheus_listen_addr,
          logging_format: logging_format,
          logging_sentry_dsn: logging_sentry_dsn,
          logging_ruby_sentry_dsn: logging_ruby_sentry_dsn,
          prometheus_grpc_latency_buckets: prometheus_grpc_latency_buckets,
          auth_token: auth_token,
          auth_transitioning: auth_transitioning,
          ruby_max_rss: ruby_max_rss,
          ruby_graceful_restart_timeout: ruby_graceful_restart_timeout,
          ruby_restart_delay: ruby_restart_delay,
        }
      )
    end

    it 'populates gitaly config.toml with custom values' do
      expect(chef_run).to render_file(config_path)
        .with_content("socket_path = '#{socket_path}'")
      expect(chef_run).to render_file(config_path)
        .with_content("bin_dir = '/opt/gitlab/embedded/bin'")
      expect(chef_run).to render_file(config_path)
        .with_content("listen_addr = 'localhost:7777'")
      expect(chef_run).to render_file(config_path)
        .with_content("prometheus_listen_addr = 'localhost:9000'")
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[logging\]\s+format = '#{logging_format}'\s+sentry_dsn = '#{logging_sentry_dsn}'\s+ruby_sentry_dsn = '#{logging_ruby_sentry_dsn}'})
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[prometheus\]\s+grpc_latency_buckets = #{Regexp.escape(prometheus_grpc_latency_buckets)}})
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[auth\]\s+token = '#{Regexp.escape(auth_token)}'\s+transitioning = true})

      gitaly_ruby_section = Regexp.new([
        %r{\[gitaly-ruby\]},
        %r{dir = "/opt/gitlab/embedded/service/gitaly-ruby"},
        %r{max_rss = #{ruby_max_rss}},
        %r{graceful_restart_timeout = '#{Regexp.escape(ruby_graceful_restart_timeout)}'},
        %r{restart_delay = '#{Regexp.escape(ruby_restart_delay)}'},
      ].map(&:to_s).join('\s+'))
      expect(chef_run).to render_file(config_path)
        .with_content(gitaly_ruby_section)
    end

    context 'when using gitaly storage configuration' do
      before do
        stub_gitlab_rb(
          gitaly: {
            storage: [
              {
                'name' => 'default',
                'path' => '/tmp/path-1'
              },
              {
                'name' => 'nfs1',
                'path' => '/mnt/nfs1'
              }
            ]
          }
        )
      end

      it 'populates gitaly config.toml with custom storages' do
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/tmp/path-1'})
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'nfs1'\s+path = '/mnt/nfs1'})
      end
    end

    context 'when using git_data_dirs storage configuration' do
      before do
        stub_gitlab_rb(
          {
            git_data_dirs:
            {
              'default' => { 'path' => '/tmp/default/git-data' },
              'nfs1' => { 'path' => '/mnt/nfs1' }
            }
          }
        )
      end

      it 'populates gitaly config.toml with custom storages' do
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/tmp/default/git-data/repositories'})
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'nfs1'\s+path = '/mnt/nfs1/repositories'})
        expect(chef_run).not_to render_file(config_path)
          .with_content('gitaly_address: "/var/opt/gitlab/gitaly/gitaly.socket"')
      end
    end
  end

  context 'when gitaly is disabled' do
    before do
      stub_gitlab_rb(gitaly: { enable: false })
    end

    it_behaves_like "disabled runit service", "gitaly"

    it 'does not create the gitaly directories' do
      expect(chef_run).not_to create_directory('/var/opt/gitlab/gitaly')
      expect(chef_run).not_to create_directory('/var/log/gitlab/gitaly')
      expect(chef_run).not_to create_directory('/opt/gitlab/etc/gitaly')
      expect(chef_run).not_to create_file('/var/opt/gitlab/gitaly/config.toml')
    end
  end

  context 'when using concurrency configuration' do
    before do
      stub_gitlab_rb(
        {
          gitaly: {
            concurrency: [
              {
                'rpc' => "/gitaly.SmartHTTPService/PostReceivePack",
                'max_per_repo' => 20
              }, {
                'rpc' => "/gitaly.SSHService/SSHUploadPack",
                'max_per_repo' => 5
              }
            ]
          }
        }
      )
    end

    it 'populates gitaly config.toml with custom concurrency configurations' do
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[\[concurrency\]\]\s+rpc = "/gitaly.SmartHTTPService/PostReceivePack"\s+max_per_repo = 20})
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[\[concurrency\]\]\s+rpc = "/gitaly.SSHService/SSHUploadPack"\s+max_per_repo = 5})
    end
  end

  shared_examples 'empty concurrency configuration' do
    it 'does not generate a gitaly concurrency configuration' do
      expect(chef_run).not_to render_file(config_path)
        .with_content(%r{\[\[concurrency\]\]})
    end
  end

  context 'when not using concurrency configuration' do
    context 'when concurrency configuration is not set' do
      before do
        stub_gitlab_rb(
          {
            gitaly: {
            }
          }
        )
      end

      it_behaves_like 'empty concurrency configuration'
    end

    context 'when concurrency configuration is empty' do
      before do
        stub_gitlab_rb(
          {
            gitaly: {
              concurrency: []
            }
          }
        )
      end

      it_behaves_like 'empty concurrency configuration'
    end
  end

  context 'populates default env variables' do
    it_behaves_like "enabled gitaly env", "TZ", ':/etc/localtime'
    it_behaves_like "enabled gitaly env", "HOME", '/var/opt/gitlab'
  end

  context 'computes env variables based on other values' do
    before do
      stub_gitlab_rb(
        {
          user: {
            home: "/my/random/path"
          }
        }
      )
    end
    it_behaves_like "enabled gitaly env", "HOME", '/my/random/path'
  end
end

describe 'gitaly::git_data_dirs' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(templatesymlink storage_directory)).converge('gitlab::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when user has not specified git_data_dir' do
    it 'defaults to correct path' do
      expect(chef_run.node['gitlab']['gitlab-rails']['repositories_storages'])
        .to eql('default' => { 'path' => '/var/opt/gitlab/git-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' })
    end
  end

  context 'when gitaly is set to use a listen_addr instead of a socket' do
    before { stub_gitlab_rb(git_data_dirs: { 'default' => { 'path' => '/tmp/user/git-data' } }, gitaly: { socket_path: '', listen_addr: 'localhost:8123' }) }

    it 'correctly sets the repository storage directories' do
      expect(chef_run.node['gitlab']['gitlab-rails']['repositories_storages'])
        .to eql('default' => { 'path' => '/tmp/user/git-data/repositories', 'gitaly_address' => 'tcp://localhost:8123' })
    end
  end

  context 'when git_data_dirs is set to multiple directories' do
    before do
      stub_gitlab_rb({
                       git_data_dirs: {
                         'default' => { 'path' => '/tmp/default/git-data' },
                         'overflow' => { 'path' => '/tmp/other/git-overflow-data' }
                       }
                     })
    end

    it 'correctly sets the repository storage directories' do
      expect(chef_run.node['gitlab']['gitlab-rails']['repositories_storages']).to eql({
                                                                                        'default' => { 'path' => '/tmp/default/git-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' },
                                                                                        'overflow' => { 'path' => '/tmp/other/git-overflow-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' }
                                                                                      })
    end
  end

  context 'when git_data_dirs is set to multiple directories with different gitaly addresses' do
    before do
      stub_gitlab_rb({
                       git_data_dirs: {
                         'default' => { 'path' => '/tmp/default/git-data' },
                         'overflow' => { 'path' => '/tmp/other/git-overflow-data', 'gitaly_address' => 'tcp://localhost:8123', 'gitaly_token' => '123secret456gitaly' }
                       }
                     })
    end

    it 'correctly sets the repository storage directories' do
      expect(chef_run.node['gitlab']['gitlab-rails']['repositories_storages']).to eql({
                                                                                        'default' => { 'path' => '/tmp/default/git-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' },
                                                                                        'overflow' => { 'path' => '/tmp/other/git-overflow-data/repositories', 'gitaly_address' => 'tcp://localhost:8123', 'gitaly_token' => '123secret456gitaly' }
                                                                                      })
    end
  end

  context 'when git_data_dirs is set with symbol keys rather than string keys' do
    before do
      with_symbol_keys = {
        default: { path: '/tmp/default/git-data' },
        overflow: { path: '/tmp/other/git-overflow-data' }
      }

      allow(Gitlab).to receive(:[]).with('git_data_dirs').and_return(with_symbol_keys)
    end

    it 'correctly sets the repository storage directories' do
      expect(chef_run.node['gitlab']['gitlab-rails']['repositories_storages']).to eql({
                                                                                        'default' => { 'path' => '/tmp/default/git-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' },
                                                                                        'overflow' => { 'path' => '/tmp/other/git-overflow-data/repositories', 'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket' }
                                                                                      })
    end
  end
end
