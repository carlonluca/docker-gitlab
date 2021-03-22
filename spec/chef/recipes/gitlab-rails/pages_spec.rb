require 'chef_helper'

RSpec.describe 'gitlab::gitlab-rails' do
  using RSpec::Parameterized::TableSyntax
  include_context 'gitlab-rails'
  include_context 'object storage config'

  let(:aws_connection_data) { JSON.parse(aws_connection_hash.to_json, symbolize_names: true) }

  describe 'Pages settings' do
    context 'with default values' do
      it 'renders gitlab.yml with Pages disabled' do
        expect(gitlab_yml[:production][:pages]).to eq(
          enabled: false,
          access_control: false,
          artifacts_server: true,
          external_http: false,
          external_https: false,
          host: nil,
          https: false,
          object_store: {
            connection: {},
            enabled: false,
            remote_directory: "pages"
          },
          path: "/var/opt/gitlab/gitlab-rails/shared/pages",
          port: nil
        )
      end
    end

    context 'with user specified values' do
      context 'when Pages deployed along with GitLab' do
        before do
          stub_gitlab_rb(
            external_url: 'https://gitlab.example.com',
            pages_external_url: 'https://pages.example.com',
            gitlab_pages: {
              access_control: true,
              artifacts_server: false,
              external_http: ['1.2.3.4']
            },
            gitlab_rails: {
              pages_path: '/random/path',
              pages_object_store_enabled: true,
              pages_object_store_remote_directory: 'foobar',
              pages_object_store_connection: aws_connection_hash
            }
          )
        end

        it 'renders gitlab.yml with user specified values' do
          expect(gitlab_yml[:production][:pages]).to eq(
            {
              enabled: true,
              access_control: true,
              path: '/random/path',
              host: 'pages.example.com',
              port: 443,
              https: true,
              external_http: true,
              external_https: false,
              artifacts_server: false,
              object_store: {
                enabled: true,
                remote_directory: 'foobar',
                connection: aws_connection_data
              }
            }
          )
        end
      end

      context 'when Pages deployed external to GitLab' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              pages_enabled: true,
              pages_path: '/random/path',
              pages_host: 'pages.example.com',
              pages_port: 443,
              pages_https: true,
              pages_object_store_enabled: true,
              pages_object_store_remote_directory: 'foobar',
              pages_object_store_connection: aws_connection_hash
            }
          )
        end

        it 'renders gitlab.yml with user specified values' do
          expect(gitlab_yml[:production][:pages]).to eq(
            {
              enabled: true,
              access_control: false,
              path: '/random/path',
              host: 'pages.example.com',
              port: 443,
              https: true,
              external_http: false,
              external_https: false,
              artifacts_server: true,
              object_store: {
                enabled: true,
                remote_directory: 'foobar',
                connection: aws_connection_data
              }
            }
          )
        end
      end

      describe 'for external HTTPS settings' do
        context 'when external_https is used' do
          before do
            stub_gitlab_rb(
              external_url: 'https://gitlab.example.com',
              pages_external_url: 'https://pages.example.com',
              gitlab_pages: {
                external_https: ['1.2.3.4']
              }
            )
          end

          it 'renders gitlab.yml with pages.external_https set to true' do
            expect(gitlab_yml[:production][:pages][:external_https]).to be true
          end
        end

        context 'when external_https_proxyv2 is used' do
          before do
            stub_gitlab_rb(
              external_url: 'https://gitlab.example.com',
              pages_external_url: 'https://pages.example.com',
              gitlab_pages: {
                external_https_proxyv2: ['1.2.3.4']
              }
            )
          end

          it 'renders gitlab.yml with pages.external_https set to true' do
            expect(gitlab_yml[:production][:pages][:external_https]).to be true
          end
        end
      end
    end
  end
end
