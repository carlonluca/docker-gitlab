require 'chef_helper'

describe 'gitlab::nginx' do
  let(:chef_runner) do
    ChefSpec::SoloRunner.new do |node|
      node.normal['gitlab']['nginx']['enable'] = true
      node.normal['package']['install-dir'] = '/opt/gitlab'
    end
  end

  let(:chef_run) do
    chef_runner.converge('gitlab::nginx')
  end

  let(:gitlab_http_config) { '/var/opt/gitlab/nginx/conf/gitlab-http.conf' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
    allow(Gitlab).to receive(:[]).with('node') { chef_runner.node }

    # generate a random number to use as error code
    @code = rand(1000)
    @nginx_errors = {
      @code => {
        'title' => 'TEST TITLE',
        'header' => 'TEST HEADER',
        'message' => 'TEST MESSAGE'
      }
    }
  end

  it 'creates a custom error_page entry when a custom error is defined' do
    allow(Gitlab).to receive(:[]).with('nginx').and_return({ 'custom_error_pages' => @nginx_errors })

    expect(chef_run).to render_file(gitlab_http_config).with_content { |content|
      expect(content).to include("error_page #{@code} /#{@code}-custom.html;")
    }
  end

  it 'renders an error template when a custom error is defined' do
    chef_runner.node.normal['gitlab']['nginx']['custom_error_pages'] = @nginx_errors
    expect(chef_run).to render_file("/opt/gitlab/embedded/service/gitlab-rails/public/#{@code}-custom.html").with_content { |content|
      expect(content).to include("TEST MESSAGE")
    }
  end

  it 'creates a standard error_page entry when no custom error is defined' do
    chef_runner.node.normal['gitlab']['nginx'].delete('custom_error_pages')
    expect(chef_run).to render_file(gitlab_http_config).with_content { |content|
      expect(content).to include("error_page 404 /404.html;")
    }
  end

  it 'enables the proxy_intercept_errors option when custom_error_pages is defined' do
    chef_runner.node.normal['gitlab']['nginx']['custom_error_pages'] = @nginx_errors
    expect(chef_run).to render_file(gitlab_http_config).with_content { |content|
      expect(content).to include("proxy_intercept_errors on")
    }
  end

  it 'uses the default proxy_intercept_errors option when custom_error_pages is not defined' do
    chef_runner.node.normal['gitlab']['nginx'].delete('custom_error_pages')
    expect(chef_run).to render_file(gitlab_http_config).with_content { |content|
      expect(content).not_to include("proxy_intercept_errors")
    }
  end
end

describe 'nginx' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }
  subject { chef_run }

  let(:gitlab_http_config) { '/var/opt/gitlab/nginx/conf/gitlab-http.conf' }
  let(:nginx_status_config) { /include \/var\/opt\/gitlab\/nginx\/conf\/nginx-status\.conf;/ }

  let(:basic_nginx_headers) do
    {
      "Host" => "$http_host",
      "X-Real-IP" => "$remote_addr",
      "X-Forwarded-Proto" => "http",
      "X-Forwarded-For" => "$proxy_add_x_forwarded_for"
    }
  end

  let(:http_conf) do
    {
      "gitlab" => "/var/opt/gitlab/nginx/conf/gitlab-http.conf",
      "mattermost" => "/var/opt/gitlab/nginx/conf/gitlab-mattermost-http.conf",
      "registry" => "/var/opt/gitlab/nginx/conf/gitlab-registry.conf",
      "pages" => "/var/opt/gitlab/nginx/conf/gitlab-pages.conf",
    }
  end

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when http external urls are being used' do
    before do
      stub_gitlab_rb(
        external_url: 'http://localhost',
        mattermost_external_url: 'http://mattermost.localhost',
        registry_external_url: 'http://registry.localhost',
        pages_external_url: 'http://pages.localhost'
      )
    end

    it 'properly sets the default nginx proxy headers' do
      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                           "Host" => "$http_host_with_default",
                                                                                           "Upgrade" => "$http_upgrade",
                                                                                           "Connection" => "$connection_upgrade"
                                                                                         }))
      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to eql(basic_nginx_headers)
      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                                      "X-Frame-Options" => "SAMEORIGIN",
                                                                                                      "Upgrade" => "$http_upgrade",
                                                                                                      "Connection" => "$connection_upgrade"
                                                                                                    }))
      expect(chef_run.node['gitlab']['pages-nginx']['proxy_set_headers']).to eql(basic_nginx_headers)
    end

    it 'supports overriding default nginx headers' do
      expect_headers = nginx_headers({ "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" })
      stub_gitlab_rb(
        "nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } },
        "mattermost_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } },
        "registry_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } }
      )

      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to include(expect_headers)
    end
  end

  context 'when https external urls are being used' do
    before do
      stub_gitlab_rb(
        external_url: 'https://localhost',
        mattermost_external_url: 'https://mattermost.localhost',
        registry_external_url: 'https://registry.localhost',
        pages_external_url: 'https://pages.localhost'
      )
    end

    it 'properly sets the default nginx proxy ssl forward headers' do
      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                           "Host" => "$http_host_with_default",
                                                                                           "X-Forwarded-Proto" => "https",
                                                                                           "X-Forwarded-Ssl" => "on",
                                                                                           "Upgrade" => "$http_upgrade",
                                                                                           "Connection" => "$connection_upgrade"
                                                                                         }))

      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                                    "X-Forwarded-Proto" => "https",
                                                                                                    "X-Forwarded-Ssl" => "on"
                                                                                                  }))

      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                                      "X-Forwarded-Proto" => "https",
                                                                                                      "X-Forwarded-Ssl" => "on",
                                                                                                      "X-Frame-Options" => "SAMEORIGIN",
                                                                                                      "Upgrade" => "$http_upgrade",
                                                                                                      "Connection" => "$connection_upgrade"
                                                                                                    }))

      expect(chef_run.node['gitlab']['pages-nginx']['proxy_set_headers']).to eql(nginx_headers({
                                                                                                 "X-Forwarded-Proto" => "https",
                                                                                                 "X-Forwarded-Ssl" => "on"
                                                                                               }))
    end

    it 'supports overriding default nginx headers' do
      expect_headers = nginx_headers({ "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp", "X-Forwarded-Ssl" => "on" })
      stub_gitlab_rb(
        "nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } },
        "mattermost_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } },
        "registry_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } },
        "pages_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" } }
      )

      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['pages-nginx']['proxy_set_headers']).to include(expect_headers)
    end

    it 'does not set ssl_client_certificate by default' do
      http_conf.each_value do |conf|
        expect(chef_run).to render_file(conf).with_content { |content|
          expect(content).not_to include("ssl_client_certificate")
        }
      end
    end

    it 'does not set ssl_verify_client by default' do
      http_conf.each_value do |conf|
        expect(chef_run).to render_file(conf).with_content { |content|
          expect(content).not_to include("ssl_verify_client")
        }
      end
    end

    it 'does not set ssl_verify_depth by default' do
      http_conf.each_value do |conf|
        expect(chef_run).to render_file(conf).with_content { |content|
          expect(content).not_to include("ssl_verify_depth")
        }
      end
    end

    it 'sets the default ssl_verify_depth when ssl_verify_client is defined' do
      verify_client = { "ssl_verify_client" => "on" }
      stub_gitlab_rb(
        "nginx" => verify_client,
        "mattermost_nginx" => verify_client,
        "registry_nginx" => verify_client,
        "pages_nginx" => verify_client
      )
      chef_run.converge('gitlab::default')
      http_conf.each_value do |conf|
        expect(chef_run).to render_file(conf).with_content { |content|
          expect(content).to include("ssl_verify_depth 1")
        }
      end
    end

    it 'applies nginx verify client settings to gitlab-http' do
      stub_gitlab_rb("nginx" => {
                       "ssl_client_certificate" => "/etc/gitlab/ssl/gitlab-http-ca.crt",
                       "ssl_verify_client" => "on",
                       "ssl_verify_depth" => "2",
                     })
      chef_run.converge('gitlab::default')
      expect(chef_run).to render_file(http_conf['gitlab']).with_content { |content|
        expect(content).to include("ssl_client_certificate /etc/gitlab/ssl/gitlab-http-ca.crt")
        expect(content).to include("ssl_verify_client on")
        expect(content).to include("ssl_verify_depth 2")
      }
    end

    it 'applies mattermost_nginx verify client settings to gitlab-mattermost-http' do
      stub_gitlab_rb("mattermost_nginx" => {
                       "ssl_client_certificate" => "/etc/gitlab/ssl/gitlab-mattermost-http-ca.crt",
                       "ssl_verify_client" => "on",
                       "ssl_verify_depth" => "3",
                     })
      chef_run.converge('gitlab::default')
      expect(chef_run).to render_file(http_conf['mattermost']).with_content { |content|
        expect(content).to include("ssl_client_certificate /etc/gitlab/ssl/gitlab-mattermost-http-ca.crt")
        expect(content).to include("ssl_verify_client on")
        expect(content).to include("ssl_verify_depth 3")
      }
    end

    it 'applies registry_nginx verify client settings to gitlab-registry' do
      stub_gitlab_rb("registry_nginx" => {
                       "ssl_client_certificate" => "/etc/gitlab/ssl/gitlab-registry-ca.crt",
                       "ssl_verify_client" => "off",
                       "ssl_verify_depth" => "5",
                     })
      chef_run.converge('gitlab::default')
      expect(chef_run).to render_file(http_conf['registry']).with_content { |content|
        expect(content).to include("ssl_client_certificate /etc/gitlab/ssl/gitlab-registry-ca.crt")
        expect(content).to include("ssl_verify_client off")
        expect(content).to include("ssl_verify_depth 5")
      }
    end

    it 'applies pages_nginx verify client settings to gitlab-pages' do
      stub_gitlab_rb("pages_nginx" => {
                       "ssl_client_certificate" => "/etc/gitlab/ssl/gitlab-pages-ca.crt",
                       "ssl_verify_client" => "on",
                       "ssl_verify_depth" => "7",
                     })
      chef_run.converge('gitlab::default')
      expect(chef_run).to render_file(http_conf['pages']).with_content { |content|
        expect(content).to include("ssl_client_certificate /etc/gitlab/ssl/gitlab-pages-ca.crt")
        expect(content).to include("ssl_verify_client on")
        expect(content).to include("ssl_verify_depth 7")
      }
    end
  end

  context 'when is enabled' do
    it 'enables nginx status by default' do
      expect(chef_run.node['gitlab']['nginx']['status']).to eql({
                                                                  "enable" => true,
                                                                  "listen_addresses" => ["*"],
                                                                  "fqdn" => "localhost",
                                                                  "port" => 8060,
                                                                  "options" => {
                                                                    "stub_status" => "on",
                                                                    "server_tokens" => "off",
                                                                    "access_log" => "off",
                                                                    "allow" => "127.0.0.1",
                                                                    "deny" => "all"
                                                                  }
                                                                })
      expect(chef_run).to render_file('/var/opt/gitlab/nginx/conf/nginx.conf').with_content(nginx_status_config)
    end

    it "supports overrading nginx status default configuration" do
      custom_nginx_status_config = {
        "enable" => true,
        "listen_addresses" => ["127.0.0.1"],
        "fqdn" => "dev.example.com",
        "port" => 9999,
        "options" => {
          "stub_status" => "on",
          "server_tokens" => "off",
          "access_log" => "on",
          "allow" => "127.0.0.1",
          "deny" => "all"
        }
      }

      stub_gitlab_rb("nginx" => {
                       "status" => custom_nginx_status_config
                     })

      chef_run.converge('gitlab::default')

      expect(chef_run.node['gitlab']['nginx']['status']).to eql(custom_nginx_status_config)
    end

    it "will not load the nginx status config if nginx status is disabled" do
      stub_gitlab_rb("nginx" => { "status" => { "enable" => false } })
      expect(chef_run).not_to render_file('/var/opt/gitlab/nginx/conf/nginx.conf').with_content(nginx_status_config)
    end
  end

  context 'when is disabled' do
    it 'should not add the nginx status config' do
      stub_gitlab_rb("nginx" => { "enable" => false })
      expect(chef_run).not_to render_file('/var/opt/gitlab/nginx/conf/nginx.conf').with_content(nginx_status_config)
    end
  end

  context 'when hsts is disabled' do
    before do
      stub_gitlab_rb(nginx: { hsts_max_age: 0 })
    end
    it { is_expected.not_to render_file(gitlab_http_config).with_content(/add_header Strict-Transport-Security/) }
  end

  it { is_expected.to render_file(gitlab_http_config).with_content(/add_header Strict-Transport-Security "max-age=31536000";/) }

  context 'when include_subdomains is enabled' do
    before do
      stub_gitlab_rb(nginx: { hsts_include_subdomains: true })
    end

    it { is_expected.to render_file(gitlab_http_config).with_content(/add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";/) }
  end

  context 'when max-age is set to 10' do
    before do
      stub_gitlab_rb(nginx: { hsts_max_age: 10 })
    end

    it { is_expected.to render_file(gitlab_http_config).with_content(/"max-age=10[^"]*"/) }
  end

  def nginx_headers(additional_headers)
    basic_nginx_headers.merge(additional_headers)
  end
end
