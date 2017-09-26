require 'chef_helper'

describe 'gitlab::gitlab-workhorse' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(env_dir)).converge('gitlab::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'with environment variables' do
    context 'by default' do
      it_behaves_like "enabled gitlab-workhorse env", "HOME", '\/var\/opt\/gitlab'
      it_behaves_like "enabled gitlab-workhorse env", "PATH", '\/opt\/gitlab\/bin:\/opt\/gitlab\/embedded\/bin:\/bin:\/usr\/bin'

      context 'when a custom env variable is specified' do
        before do
          stub_gitlab_rb(gitlab_workhorse: { env: { 'IAM' => 'CUSTOMVAR' } })
        end

        it_behaves_like "enabled gitlab-workhorse env", "IAM", 'CUSTOMVAR'
      end
    end
  end

  context 'without api rate limiting' do
    it 'correctly renders out the workhorse service file' do
      expect(chef_run).not_to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiLimit/)
      expect(chef_run).not_to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiQueueDuration/)
      expect(chef_run).not_to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiQueueLimit/)
    end
  end

  context 'with api rate limiting' do
    before do
      stub_gitlab_rb(gitlab_workhorse: { api_limit: 3, api_queue_limit: 6, api_queue_duration: '1m' })
    end

    it 'correctly renders out the workhorse service file' do
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiLimit 3 \\/)
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiQueueDuration 1m \\/)
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiQueueLimit 6 \\/)
    end
  end

  context 'without prometheus listen address' do
    before do
      stub_gitlab_rb(gitlab_workhorse: {})
    end

    it 'correctly renders out the workhorse service file' do
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run")
      expect(chef_run).not_to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-prometheusListenAddr/)
    end
  end

  context 'with prometheus listen address' do
    before do
      stub_gitlab_rb(gitlab_workhorse: { prometheus_listen_addr: ':9100' })
    end

    it 'correctly renders out the workhorse service file' do
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-prometheusListenAddr :9100 \\/)
    end
  end

  context 'without api ci long polling duration defined' do
    it 'correctly renders out the workhorse service file' do
      expect(chef_run).not_to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiCiLongPollingDuration/)
    end
  end

  context 'with api ci long polling duration defined' do
    before do
      stub_gitlab_rb(gitlab_workhorse: { api_ci_long_polling_duration: "60s" })
    end

    it 'correctly renders out the workhorse service file' do
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-apiCiLongPollingDuration 60s/)
    end
  end

  context 'with default value for working directory' do
    it 'should generate config file in the correct directory' do
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml")
    end
  end

  context 'with working directory specified' do
    before do
      stub_gitlab_rb(gitlab_workhorse: { dir: "/home/random/dir" })
    end
    it 'should generate config file in the correct directory' do
      expect(chef_run).to render_file("/home/random/dir/config.toml")
    end
  end

  context 'with default values for redis' do
    it 'should generate config file' do
      content_url = 'URL = "unix:/var/opt/gitlab/redis/redis.socket"'
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_url)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(/Sentinel/)
    end

    it 'should pass config file to workhorse' do
      expect(chef_run).to render_file("/opt/gitlab/sv/gitlab-workhorse/run").with_content(/\-config config.toml/)
    end
  end

  context 'with host/port/password values for redis specified and socket disabled' do
    before do
      stub_gitlab_rb(
        gitlab_rails: {
          redis_host: "10.0.15.1",
          redis_port: "1234",
          redis_password: 'examplepassword'
        }
      )
    end

    it 'should generate config file with the specified values' do
      content_url = 'URL = "tcp://10.0.15.1:1234/"'
      content_password = 'Password = "examplepassword"'
      content_sentinel = 'Sentinel'
      content_sentinel_master = 'SentinelMaster'
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_url)
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_password)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_sentinel)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_sentinel_master)
    end
  end

  context 'with socket for redis specified' do
    before do
      stub_gitlab_rb(gitlab_rails: { redis_socket: "/home/random/path.socket", redis_password: 'examplepassword' })
    end

    it 'should generate config file with the specified values' do
      content_url = 'URL = "unix:/home/random/path.socket"'
      content_password = 'Password = "examplepassword"'
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_url)
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_password)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(/Sentinel/)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(/SentinelMaster/)
    end
  end

  context 'with Sentinels specified with default master' do
    before do
      stub_gitlab_rb(
        gitlab_rails: {
          redis_sentinels: [
            { 'host' => '127.0.0.1', 'port' => 2637 },
            { 'host' => '127.0.8.1', 'port' => 1234 }
          ]
        }
      )
    end

    it 'should generate config file with the specified values' do
      content = 'Sentinel = ["tcp://127.0.0.1:2637", "tcp://127.0.8.1:1234"]'
      content_url = 'URL ='
      content_sentinel_master = 'SentinelMaster = "gitlab-redis"'
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content)
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_sentinel_master)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_url)
    end
  end

  context 'with Sentinels and master specified' do
    before do
      stub_gitlab_rb(
        gitlab_rails: {
          redis_sentinels: [
            { 'host' => '127.0.0.1', 'port' => 26379 },
            { 'host' => '127.0.8.1', 'port' => 12345 }
          ]
        },
        redis: {
          master_name: 'examplemaster',
          master_password: 'examplepassword'
        }
      )
    end

    it 'should generate config file with the specified values' do
      content = 'Sentinel = ["tcp://127.0.0.1:26379", "tcp://127.0.8.1:12345"]'
      content_sentinel_master = 'SentinelMaster = "examplemaster"'
      content_sentinel_password = 'Password = "examplepassword"'
      content_url = 'URL ='
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content)
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_sentinel_master)
      expect(chef_run).to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_sentinel_password)
      expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-workhorse/config.toml").with_content(content_url)
    end
  end
end
