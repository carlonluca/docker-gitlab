require 'chef_helper'

describe 'nginx' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }
  let(:nginx_status_config) { /include \/var\/opt\/gitlab\/nginx\/conf\/nginx-status\.conf;/ }

  let(:basic_nginx_headers) do
    {
      "Host" => "$http_host",
      "X-Real-IP" => "$remote_addr",
      "X-Forwarded-Proto" => "http",
      "X-Forwarded-For" => "$proxy_add_x_forwarded_for"
    }
  end

  before { allow(Gitlab).to receive(:[]).and_call_original }

  context 'when http external urls are being used' do
    before do
      stub_gitlab_rb(
        external_url: 'http://localhost',
        mattermost_external_url: 'http://mattermost.localhost',
        registry_external_url: 'http://registry.localhost'
      )
    end

    it 'properly sets the default nginx proxy headers' do
      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to eql(basic_nginx_headers)
      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to eql(basic_nginx_headers)
      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to eql(nginx_headers({
        "X-Frame-Options" => "SAMEORIGIN",
        "Upgrade" => "$http_upgrade",
        "Connection" => "$connection_upgrade"
      }))
    end

    it 'supports overriding default nginx headers' do
      expect_headers = nginx_headers({ "Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp" })
      stub_gitlab_rb(
        "nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } },
        "mattermost_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } },
        "registry_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } }
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
        registry_external_url: 'https://registry.localhost'
      )
    end

    it 'properly sets the default nginx proxy ssl forward headers' do
      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to eql(nginx_headers({
        "X-Forwarded-Proto" => "https",
        "X-Forwarded-Ssl" => "on"
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
    end

    it 'supports overriding default nginx headers' do
      expect_headers = nginx_headers({"Host" => "nohost.example.com", "X-Forwarded-Proto" => "ftp", "X-Forwarded-Ssl" => "on" })
      stub_gitlab_rb(
        "nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } },
        "mattermost_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } },
        "registry_nginx" => { proxy_set_headers: { "Host" => "nohost.example.com",  "X-Forwarded-Proto" => "ftp" } }
      )

      expect(chef_run.node['gitlab']['nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['mattermost-nginx']['proxy_set_headers']).to include(expect_headers)
      expect(chef_run.node['gitlab']['registry-nginx']['proxy_set_headers']).to include(expect_headers)
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
      expect(chef_run).to_not render_file('/var/opt/gitlab/nginx/conf/nginx.conf').with_content(nginx_status_config)
    end
  end

  context 'when is disabled' do
    it 'should not add the nginx status config' do
      stub_gitlab_rb("nginx" => { "enable" => false })
      expect(chef_run).to_not render_file('/var/opt/gitlab/nginx/conf/nginx.conf').with_content(nginx_status_config)
    end
  end

  def nginx_headers(additional_headers)
    basic_nginx_headers.merge(additional_headers)
  end
end
