require 'chef_helper'

describe 'gitlab::gitlab-rails' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(runit_service)).converge('gitlab::default') }
  let(:redis_instances) { %w(cache queues shared_state) }
  let(:config_dir) { '/var/opt/gitlab/gitlab-rails/etc/' }
  let(:default_vars) do
    {
      'HOME' => '/var/opt/gitlab',
      'RAILS_ENV' => 'production',
      'SIDEKIQ_MEMORY_KILLER_MAX_RSS' => '2000000',
      'BUNDLE_GEMFILE' => '/opt/gitlab/embedded/service/gitlab-rails/Gemfile',
      'PATH' => '/opt/gitlab/bin:/opt/gitlab/embedded/bin:/bin:/usr/bin',
      'ICU_DATA' => '/opt/gitlab/embedded/share/icu/current',
      'PYTHONPATH' => '/opt/gitlab/embedded/lib/python3.4/site-packages',
      'EXECJS_RUNTIME' => 'Disabled',
      'TZ' => ':/etc/localtime',
      'LD_PRELOAD' => '/opt/gitlab/embedded/lib/libjemalloc.so',
    }
  end

  before do
    allow(Gitlab).to receive(:[]).and_call_original
    allow(File).to receive(:symlink?).and_call_original
  end

  context 'when manage-storage-directories is disabled' do
    cached(:chef_run) do
      RSpec::Mocks.with_temporary_scope do
        stub_gitlab_rb(gitlab_rails: { shared_path: '/tmp/shared',
                                       uploads_directory: '/tmp/uploads',
                                       builds_directory: '/tmp/builds' },
                       manage_storage_directories: { enable: false })
      end

      ChefSpec::SoloRunner.new.converge('gitlab::default')
    end

    it 'does not create the shared directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared')
    end

    it 'does not create the artifacts directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared/artifacts')
    end

    it 'does not create the external-diffs directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared/external-diffs')
    end

    it 'does not create the lfs storage directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared/lfs-objects')
    end

    it 'does not create the packages storage directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared/packages')
    end

    it 'does not create the uploads storage directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/uploads')
    end

    it 'does not create the ci builds directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/builds')
    end

    it 'does not create the GitLab pages directory' do
      expect(chef_run).not_to run_ruby_block('directory resource: /tmp/shared/pages')
    end
  end

  context 'when manage-storage-directories is enabled' do
    cached(:chef_run) do
      RSpec::Mocks.with_temporary_scope do
        stub_gitlab_rb(gitlab_rails: { shared_path: '/tmp/shared',
                                       uploads_directory: '/tmp/uploads' },
                       gitlab_ci: { builds_directory: '/tmp/builds' })
      end

      ChefSpec::SoloRunner.converge('gitlab::default')
    end

    it 'creates the shared directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared').with(owner: 'git', mode: '0751')
    end

    it 'creates the artifacts directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/artifacts').with(owner: 'git', mode: '0700')
    end

    it 'creates the external-diffs directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/external-diffs').with(owner: 'git', mode: '0700')
    end

    it 'creates the lfs storage directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/lfs-objects').with(owner: 'git', mode: '0700')
    end

    it 'creates the packages directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/packages').with(owner: 'git', mode: '0700')
    end

    it 'creates the uploads directory' do
      expect(chef_run).to create_storage_directory('/tmp/uploads').with(owner: 'git', mode: '0700')
    end

    it 'creates the ci builds directory' do
      expect(chef_run).to create_storage_directory('/tmp/builds').with(owner: 'git', mode: '0700')
    end

    it 'creates the GitLab pages directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/pages').with(owner: 'git', mode: '0750')
    end

    it 'creates the shared tmp directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/tmp').with(owner: 'git', mode: '0700')
    end

    it 'creates the shared cache directory' do
      expect(chef_run).to create_storage_directory('/tmp/shared/cache').with(owner: 'git', mode: '0700')
    end
  end

  context 'with redis settings' do
    let(:config_file) { '/var/opt/gitlab/gitlab-rails/etc/resque.yml' }
    let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(templatesymlink)).converge('gitlab::default') }

    context 'and default configuration' do
      it 'creates the config file with the required redis settings' do
        expect(chef_run).to create_templatesymlink('Create a resque.yml and create a symlink to Rails root').with_variables(
          hash_including(
            redis_url: URI('unix:/var/opt/gitlab/redis/redis.socket'),
            redis_sentinels: [],
            redis_enable_client: true
          )
        )

        expect(chef_run).to render_file(config_file).with_content { |content|
          expect(content).to match(%r(url: unix:/var/opt/gitlab/redis/redis.socket$))
          expect(content).not_to match(/id:/)
        }
      end

      it 'does not render the separate instance configurations' do
        redis_instances.each do |instance|
          expect(chef_run).not_to render_file("#{config_dir}redis.#{instance}.yml")
        end
      end
    end

    context 'and custom configuration' do
      before do
        stub_gitlab_rb(
          gitlab_rails: {
            redis_host: 'redis.example.com',
            redis_port: 8888,
            redis_database: 2,
            redis_password: 'mypass',
            redis_enable_client: false
          }
        )
      end

      it 'creates the config file with custom host, port, password and database' do
        expect(chef_run).to create_templatesymlink('Create a resque.yml and create a symlink to Rails root').with_variables(
          hash_including(
            redis_url: URI('redis://:mypass@redis.example.com:8888/2'),
            redis_sentinels: [],
            redis_enable_client: false
          )
        )

        expect(chef_run).to render_file(config_file).with_content { |content|
          expect(content).to match(%r(url: redis://:mypass@redis.example.com:8888/2))
          expect(content).to match(/id:$/)
        }
      end
    end

    context 'with multiple instances' do
      before do
        stub_gitlab_rb(
          gitlab_rails: {
            redis_cache_instance: "redis://:fakepass@fake.redis.cache.com:8888/2",
            redis_cache_sentinels: [
              { host: 'cache', port: '1234' },
              { host: 'cache', port: '3456' }
            ],
            redis_queues_instance: "redis://:fakepass@fake.redis.queues.com:8888/2",
            redis_queues_sentinels: [
              { host: 'queues', port: '1234' },
              { host: 'queues', port: '3456' }
            ],
            redis_shared_state_instance: "redis://:fakepass@fake.redis.shared_state.com:8888/2",
            redis_shared_state_sentinels: [
              { host: 'shared_state', port: '1234' },
              { host: 'shared_state', port: '3456' }
            ]
          }
        )
      end

      it 'render separate config files' do
        redis_instances.each do |instance|
          expect(chef_run).to create_templatesymlink("Create a redis.#{instance}.yml and create a symlink to Rails root").with_variables(
            redis_url: "redis://:fakepass@fake.redis.#{instance}.com:8888/2",
            redis_sentinels: [{ "host" => instance, "port" => "1234" }, { "host" => instance, "port" => "3456" }]
          )
        end
      end

      it 'still renders the default configuration file' do
        expect(chef_run).to create_templatesymlink('Create a resque.yml and create a symlink to Rails root')
      end
    end
  end

  context 'creating gitlab.yml' do
    gitlab_yml_path = '/var/opt/gitlab/gitlab-rails/etc/gitlab.yml'
    let(:gitlab_yml) { chef_run.template(gitlab_yml_path) }
    let(:gitlab_yml_templatesymlink) { chef_run.templatesymlink('Create a gitlab.yml and create a symlink to Rails root') }

    let(:aws_connection_hash) do
      {
        'provider' => 'AWS',
        'region' => 'eu-west-1',
        'aws_access_key_id' => 'AKIAKIAKI',
        'aws_secret_access_key' => 'secret123'
      }
    end

    shared_examples 'sets the connection in YAML' do
      it do
        expect(chef_run).to render_file(gitlab_yml_path)
          .with_content(/connection:\s{"provider":"AWS"/)
        expect(chef_run).to render_file(gitlab_yml_path)
          .with_content(/"region":"eu-west-1"/)
        expect(chef_run).to render_file(gitlab_yml_path)
          .with_content(/"aws_access_key_id":"AKIAKIAKI"/)
        expect(chef_run).to render_file(gitlab_yml_path)
          .with_content(/"aws_secret_access_key":"secret123"/)
      end
    end

    # NOTE: Test if we pass proper notifications to other resources
    context 'rails cache management' do
      before do
        allow_any_instance_of(OmnibusHelper).to receive(:not_listening?)
          .and_return(false)
      end

      it 'should notify rails cache clear resource' do
        expect(gitlab_yml_templatesymlink).to notify('execute[clear the gitlab-rails cache]')
      end

      it 'should still notify rails cache clear resource if disabled' do
        stub_gitlab_rb(gitlab_rails: { rake_cache_clear: false })

        expect(gitlab_yml_templatesymlink).to notify(
          'execute[clear the gitlab-rails cache]')
        expect(chef_run).not_to run_execute(
          'clear the gitlab-rails cache')
      end
    end

    context 'for settings regarding object storage for artifacts' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'artifacts_object_store_enabled' => false,
            'artifacts_object_store_direct_upload' => false,
            'artifacts_object_store_background_upload' => true,
            'artifacts_object_store_proxy_download' => false,
            'artifacts_object_store_remote_directory' => 'artifacts'
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           artifacts_object_store_enabled: true,
                           artifacts_object_store_direct_upload: true,
                           artifacts_object_store_background_upload: false,
                           artifacts_object_store_proxy_download: true,
                           artifacts_object_store_remote_directory: 'mepmep',
                           artifacts_object_store_connection: aws_connection_hash
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'artifacts_object_store_enabled' => true,
              'artifacts_object_store_direct_upload' => true,
              'artifacts_object_store_background_upload' => false,
              'artifacts_object_store_proxy_download' => true,
              'artifacts_object_store_remote_directory' => 'mepmep',
              'artifacts_object_store_connection' => aws_connection_hash
            )
          )
        end
      end
    end

    context 'for settings regarding object storage for external diffs' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'external_diffs_object_store_enabled' => false,
            'external_diffs_object_store_direct_upload' => false,
            'external_diffs_object_store_background_upload' => true,
            'external_diffs_object_store_proxy_download' => false,
            'external_diffs_object_store_remote_directory' => 'external-diffs'
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           external_diffs_object_store_enabled: true,
                           external_diffs_object_store_direct_upload: true,
                           external_diffs_object_store_background_upload: false,
                           external_diffs_object_store_proxy_download: true,
                           external_diffs_object_store_remote_directory: 'mepmep',
                           external_diffs_object_store_connection: aws_connection_hash
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'external_diffs_object_store_enabled' => true,
              'external_diffs_object_store_direct_upload' => true,
              'external_diffs_object_store_background_upload' => false,
              'external_diffs_object_store_proxy_download' => true,
              'external_diffs_object_store_remote_directory' => 'mepmep',
              'external_diffs_object_store_connection' => aws_connection_hash
            )
          )
        end
      end
    end

    context 'for settings regarding object storage for lfs' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'lfs_object_store_enabled' => false,
            'lfs_object_store_direct_upload' => false,
            'lfs_object_store_background_upload' => true,
            'lfs_object_store_proxy_download' => false,
            'lfs_object_store_remote_directory' => 'lfs-objects'
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           lfs_object_store_enabled: true,
                           lfs_object_store_direct_upload: true,
                           lfs_object_store_background_upload: false,
                           lfs_object_store_proxy_download: true,
                           lfs_object_store_remote_directory: 'mepmep',
                           lfs_object_store_connection: aws_connection_hash
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'lfs_object_store_enabled' => true,
              'lfs_object_store_direct_upload' => true,
              'lfs_object_store_background_upload' => false,
              'lfs_object_store_proxy_download' => true,
              'lfs_object_store_remote_directory' => 'mepmep',
              'lfs_object_store_connection' => aws_connection_hash
            )
          )
        end
      end
    end

    context 'for settings regarding object storage for uploads' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'uploads_storage_path' => '/opt/gitlab/embedded/service/gitlab-rails/public',
            'uploads_object_store_enabled' => false,
            'uploads_object_store_direct_upload' => false,
            'uploads_object_store_background_upload' => true,
            'uploads_object_store_proxy_download' => false,
            'uploads_object_store_remote_directory' => 'uploads'
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           uploads_base_dir: 'mapmap',
                           uploads_object_store_enabled: true,
                           uploads_object_store_direct_upload: true,
                           uploads_object_store_background_upload: false,
                           uploads_object_store_proxy_download: true,
                           uploads_object_store_remote_directory: 'mepmep',
                           uploads_object_store_connection: aws_connection_hash
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'uploads_base_dir' => 'mapmap',
              'uploads_object_store_enabled' => true,
              'uploads_object_store_direct_upload' => true,
              'uploads_object_store_background_upload' => false,
              'uploads_object_store_proxy_download' => true,
              'uploads_object_store_remote_directory' => 'mepmep',
              'uploads_object_store_connection' => aws_connection_hash
            )
          )
        end
      end
    end

    context 'for settings regarding object storage for packages' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'packages_storage_path' => '/var/opt/gitlab/gitlab-rails/shared/packages',
            'packages_object_store_enabled' => false,
            'packages_object_store_direct_upload' => false,
            'packages_object_store_background_upload' => true,
            'packages_object_store_proxy_download' => false,
            'packages_object_store_remote_directory' => 'packages'
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           packages_object_store_enabled: true,
                           packages_object_store_direct_upload: true,
                           packages_object_store_background_upload: false,
                           packages_object_store_proxy_download: true,
                           packages_object_store_remote_directory: 'mepmep',
                           packages_object_store_connection: aws_connection_hash
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'packages_object_store_enabled' => true,
              'packages_object_store_direct_upload' => true,
              'packages_object_store_background_upload' => false,
              'packages_object_store_proxy_download' => true,
              'packages_object_store_remote_directory' => 'mepmep',
              'packages_object_store_connection' => aws_connection_hash
            )
          )
        end
      end
    end

    describe 'pseudonymizer settings' do
      it 'allows not setting any values' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'pseudonymizer_manifest' => nil,
            'pseudonymizer_upload_connection' => {},
            'pseudonymizer_upload_remote_directory' => nil
          )
        )
      end

      context 'with values' do
        before do
          stub_gitlab_rb(gitlab_rails: {
                           pseudonymizer_manifest: 'another/path/manifest.yml',
                           pseudonymizer_upload_remote_directory: 'gitlab-pseudo',
                           pseudonymizer_upload_connection: aws_connection_hash,
                         })
        end

        it "sets the object storage values" do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pseudonymizer_manifest' => 'another/path/manifest.yml',
              'pseudonymizer_upload_connection' => aws_connection_hash,
              'pseudonymizer_upload_remote_directory' => 'gitlab-pseudo'
            )
          )
        end
      end
    end

    describe 'repositories storages' do
      it 'sets specified properties' do
        stub_gitlab_rb(
          git_data_dirs: {
            "second_storage" => {
              "path" => "tmp/storage"
            }
          }
        )

        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'repositories_storages' => {
              'second_storage' => {
                'path' => 'tmp/storage/repositories',
                'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket'
              }
            }
          )
        )
      end

      it 'sets the defaults' do
        default_storages = {
          'default' => {
            'path' => '/var/opt/gitlab/git-data/repositories',
            'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket'
          }
        }
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            'repositories_storages' => default_storages
          )
        )
      end
    end

    context 'pages settings' do
      context 'pages access control is enabled' do
        it 'sets the hint true' do
          stub_gitlab_rb(
            external_url: 'https://gitlab.example.com',
            pages_external_url: 'https://pages.example.com',
            gitlab_pages: {
              external_http: ['external_pages.example.com', 'localhost:9000'],
              external_https: ['external_pages.example.com', 'localhost:9001'],
              access_control: true
            }
          )

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pages_enabled' => true,
              pages_access_control: true
            )
          )
        end
      end

      context 'pages access control is disabled' do
        it 'sets the hint false' do
          stub_gitlab_rb(
            external_url: 'https://gitlab.example.com',
            pages_external_url: 'https://pages.example.com',
            gitlab_pages: {
              external_http: ['external_pages.example.com', 'localhost:9000'],
              external_https: ['external_pages.example.com', 'localhost:9001'],
              access_control: false
            }
          )
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pages_enabled' => true,
              pages_access_control: false
            )
          )
        end
      end
    end

    context 'mattermost settings' do
      context 'mattermost is configured' do
        it 'exposes the mattermost host' do
          stub_gitlab_rb(mattermost: { enable: true },
                         mattermost_external_url: 'http://mattermost.domain.com')

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              mattermost_host: 'http://mattermost.domain.com'
            )
          )
        end
      end

      context 'mattermost is not configured' do
        it 'has empty values' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              mattermost_enabled: false,
              mattermost_host: nil
            )
          )
        end
      end

      context 'mattermost on another server' do
        it 'sets the mattermost host' do
          stub_gitlab_rb(gitlab_rails: { mattermost_host: 'http://my.host.com' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              mattermost_enabled: true,
              mattermost_host: 'http://my.host.com'
            )
          )
        end

        context 'values set twice' do
          it 'sets the mattermost external url' do
            stub_gitlab_rb(mattermost: { enable: true },
                           mattermost_external_url: 'http://my.url.com',
                           gitlab_rails: { mattermost_host: 'http://do.not/setme' })

            expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
              hash_including(
                mattermost_enabled: true,
                mattermost_host: 'http://my.url.com'
              )
            )
          end
        end
      end
    end

    context 'LDAP server configuration' do
      context 'LDAP servers are configured' do
        let(:ldap_servers_config) do
          <<-EOS
            main:
              label: 'LDAP Primary'
              host: 'primary.ldap'
              port: 389
              uid: 'uid'
              encryption: 'plain'
              password: 's3cr3t'
              base: 'dc=example,dc=com'
              user_filter: ''

            secondary:
              label: 'LDAP Secondary'
              host: 'secondary.ldap'
              port: 389
              uid: 'uid'
              encryption: 'plain'
              bind_dn: 'dc=example,dc=com'
              password: 's3cr3t'
              smartcard_auth: 'required'
              base: ''
              user_filter: ''
          EOS
        end

        it 'exposes the LDAP server configuration' do
          stub_gitlab_rb(
            gitlab_rails: {
              ldap_enabled: true,
              ldap_servers: YAML.safe_load(ldap_servers_config)
            })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              "ldap_enabled" => true,
              "ldap_servers" => YAML.safe_load(ldap_servers_config)
            )
          )
        end
      end

      context 'LDAP is not configured' do
        it 'does not enable LDAP' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              "ldap_enabled" => false
            )
          )
        end
      end
    end

    context 'smartcard authentication settings' do
      context 'smartcard authentication is configured' do
        it 'exposes the smartcard authentication settings' do
          stub_gitlab_rb(
            gitlab_rails: {
              smartcard_enabled: true
            }
          )

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'smartcard_enabled' => true,
              'smartcard_ca_file' => '/etc/gitlab/ssl/CA.pem',
              'smartcard_client_certificate_required_port' => 3444
            )
          )
        end
      end

      context 'smartcard authentication is disabled' do
        context 'smartcard authentication is not configured' do
          it 'does not enable smartcard authentication' do
            expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'smartcard_enabled' => false
              )
            )
          end
        end
      end
    end

    context 'omniauth settings' do
      context 'enabled setting' do
        it 'defaults to nil (enabled)' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_enabled' => nil
            )
          )
        end

        it 'can be explicitly enabled' do
          stub_gitlab_rb(gitlab_rails: { omniauth_enabled: true })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_enabled' => true
            )
          )
        end

        it 'can be disabled' do
          stub_gitlab_rb(gitlab_rails: { omniauth_enabled: false })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_enabled' => false
            )
          )
        end
      end

      context 'sync email from omniauth provider is configured' do
        it 'sets the omniauth provider' do
          stub_gitlab_rb(gitlab_rails: { omniauth_sync_email_from_provider: 'cas3' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_email_from_provider' => 'cas3'
            )
          )
        end
      end

      context 'sync email from omniauth provider is not configured' do
        it 'does not include the sync email from omniauth provider setting' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_email_from_provider' => nil
            )
          )
        end
      end

      context 'sync profile from omniauth provider is not configured' do
        it 'sets the sync profile from provider to []' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_profile_from_provider' => nil
            )
          )
        end
      end

      context 'sync profile from omniauth provider is configured to array' do
        it 'sets the sync profile from provider to [\'cas3\']' do
          stub_gitlab_rb(gitlab_rails: { omniauth_sync_profile_from_provider: ['cas3'] })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_profile_from_provider' => ['cas3']
            )
          )
        end
      end

      context 'sync profile from omniauth provider is configured to true' do
        it 'sets the sync profile from provider to true' do
          stub_gitlab_rb(gitlab_rails: { omniauth_sync_profile_from_provider: true })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_profile_from_provider' => true
            )
          )
        end
      end

      context 'sync profile attributes is configured to [\"email\", \"name\"]' do
        it 'sets the sync profile attributes to [\"email\", \"name\"]' do
          stub_gitlab_rb(gitlab_rails: { omniauth_sync_profile_attributes: %w(email name) })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_profile_attributes' => %w[email name]
            )
          )
        end
      end

      context 'sync profile attributes is configured to true' do
        it 'sets the sync profile attributes to true' do
          stub_gitlab_rb(gitlab_rails: { omniauth_sync_profile_attributes: true })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'omniauth_sync_profile_attributes' => true
            )
          )
        end
      end
    end

    context 'Sidekiq log_format' do
      it 'sets the Sidekiq log_format to default' do
        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            sidekiq: hash_including(
              'log_format' => 'default'
            )
          )
        )
        expect(chef_run).to render_file("/opt/gitlab/sv/sidekiq/log/run").with_content(/svlogd -tt/)
      end

      it 'sets the Sidekiq log_format to json' do
        stub_gitlab_rb(sidekiq: { log_format: 'json' })

        expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
          hash_including(
            sidekiq: hash_including(
              'log_format' => 'json'
            )
          )
        )
        expect(chef_run).not_to render_file("/opt/gitlab/sv/sidekiq/log/run").with_content(/-tt/)
      end
    end

    context 'sidekiq-cluster' do
      let(:chef_run) do
        ChefSpec::SoloRunner.new.converge('gitlab-ee::default')
      end

      before do
        stub_gitlab_rb(sidekiq_cluster: { enable: true, queue_groups: 'gitlab_shell' })
        allow_any_instance_of(OmnibusHelper).to receive(:service_up?).and_return(false)
        allow_any_instance_of(OmnibusHelper).to receive(:service_up?).with('sidekiq-cluster').and_return(true)
        stub_should_notify?('sidekiq-cluster', true)
      end

      describe 'gitlab.yml' do
        let(:templatesymlink) { chef_run.templatesymlink('Create a gitlab.yml and create a symlink to Rails root') }

        it 'template triggers notifications' do
          expect(templatesymlink).not_to notify('service[sidekiq]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq-cluster]').to(:restart).delayed
        end
      end
    end

    context 'GitLab Geo settings' do
      let(:chef_run) do
        ChefSpec::SoloRunner.new.converge('gitlab-ee::default')
      end

      context 'when repository sync worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_repository_sync_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_sync_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when repository sync worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_sync_worker_cron' => nil
            )
          )
        end
      end

      context 'when geo prune event log worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_prune_event_log_worker_cron: '5 4 3 2 1' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_prune_event_log_worker_cron' => '5 4 3 2 1'
            )
          )
        end
      end

      context 'when geo prune event log worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_excluding(
              'geo_prune_event_log_worker_cron'
            )
          )
        end
      end

      context 'when file download dispatch worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_file_download_dispatch_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_file_download_dispatch_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when file download dispatch worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_file_download_dispatch_worker_cron' => nil
            )
          )
        end
      end

      context 'when repository verification primary batch worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_repository_verification_primary_batch_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_verification_primary_batch_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when repository verification primary batch worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_verification_primary_batch_worker_cron' => nil
            )
          )
        end
      end

      context 'when repository verification secondary scheduler worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_repository_verification_secondary_scheduler_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_verification_secondary_scheduler_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when repository verification secondary scheduler worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_repository_verification_secondary_scheduler_worker_cron' => nil
            )
          )
        end
      end

      context 'when migrated local files cleanup worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { geo_migrated_local_files_clean_up_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_migrated_local_files_clean_up_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when migrated local files cleanup worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'geo_migrated_local_files_clean_up_worker_cron' => nil
            )
          )
        end
      end

      context 'when pseudonymizer worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { pseudonymizer_worker_cron: '1 2 3 4 5' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pseudonymizer_worker_cron' => '1 2 3 4 5'
            )
          )
        end
      end

      context 'when pseudonymizer worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pseudonymizer_worker_cron' => nil
            )
          )
        end
      end
    end

    context 'Scheduled Pipeline settings' do
      context 'when the cron pattern is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { pipeline_schedule_worker_cron: '41 * * * *' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pipeline_schedule_worker_cron' => '41 * * * *'
            )
          )
        end
      end

      context 'when the cron pattern is not configured' do
        it 'sets no value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pipeline_schedule_worker_cron' => nil
            )
          )
        end
      end
    end

    context 'Monitoring settings' do
      context 'by default' do
        it 'whitelists local subnet' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'monitoring_whitelist' => ['127.0.0.0/8', '::1/128']
            )
          )
        end

        it 'sampler will sample every 10s' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'monitoring_unicorn_sampler_interval' => 10
            )
          )
        end
      end

      context 'when ip whitelist is configured' do
        before do
          stub_gitlab_rb(gitlab_rails: { monitoring_whitelist: %w(1.0.0.0 2.0.0.0) })
        end
        it 'sets the whitelist' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'monitoring_whitelist' => ['1.0.0.0', '2.0.0.0']
            )
          )
        end
      end

      context 'when unicorn sampler interval is configured' do
        before do
          stub_gitlab_rb(gitlab_rails: { monitoring_unicorn_sampler_interval: 123 })
        end

        it 'sets the interval value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'monitoring_unicorn_sampler_interval' => 123
            )
          )
        end
      end
    end

    context 'Gitaly settings' do
      context 'when a global token is set' do
        let(:token) { '123secret456gitaly' }

        it 'renders the token in the gitaly section' do
          stub_gitlab_rb(gitlab_rails: { gitaly_token: token })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'gitaly_token' => '123secret456gitaly'
            )
          )
        end
      end
    end

    context 'GitLab Shell settings' do
      context 'when git_timeout is configured' do
        it 'sets the git_timeout value' do
          stub_gitlab_rb(gitlab_rails: { gitlab_shell_git_timeout: 1000 })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'gitlab_shell_git_timeout' => 1000
            )
          )
        end
      end

      context 'when git_timeout is not configured' do
        it 'sets git_timeout value to default' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'gitlab_shell_git_timeout' => 10800
            )
          )
        end
      end
    end

    context 'GitLab LDAP cron_jobs settings' do
      context 'when ldap user sync worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { ldap_sync_worker_cron: '40 2 * * *' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_sync_worker_cron' => '40 2 * * *'
            )
          )
        end
      end

      context 'when ldap user sync worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_sync_worker_cron' => nil
            )
          )
        end
      end

      context 'when ldap group sync worker is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { ldap_group_sync_worker_cron: '1 0 * * *' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_group_sync_worker_cron' => '1 0 * * *'
            )
          )
        end
      end

      context 'when ldap group sync worker is not configured' do
        it 'does not set the cron value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_group_sync_worker_cron' => nil
            )
          )
        end
      end
    end

    context 'GitLab LDAP settings' do
      context 'when ldap lowercase_usernames setting is' do
        it 'set, sets the setting value' do
          stub_gitlab_rb(gitlab_rails: { ldap_lowercase_usernames: true })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_lowercase_usernames' => true
            )
          )
        end

        it 'not set, sets default value to blank' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ldap_lowercase_usernames' => nil
            )
          )
        end
      end
    end

    context 'Rescue stale live trace settings' do
      context 'when the cron pattern is configured' do
        it 'sets the cron value' do
          stub_gitlab_rb(gitlab_rails: { ci_archive_traces_cron_worker_cron: '17 * * * *' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'ci_archive_traces_cron_worker_cron' => '17 * * * *'
            )
          )
        end
      end

      context 'when the cron pattern is not configured' do
        it 'sets no value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_excluding(
              'ci_archive_traces_cron_worker_cron'
            )
          )
        end
      end
    end

    context 'GitLab Pages verification cron job settings' do
      context 'when the cron pattern is configured' do
        it 'sets the value' do
          stub_gitlab_rb(gitlab_rails: { pages_domain_verification_cron_worker: '1 0 * * *' })

          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pages_domain_verification_cron_worker' => '1 0 * * *'
            )
          )
        end
      end
      context 'when pages domain verification cron worker is not configured' do
        it ' sets no value' do
          expect(chef_run).to create_templatesymlink('Create a gitlab.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'pages_domain_verification_cron_worker' => nil
            )
          )
        end
      end
    end
  end

  context 'with environment variables' do
    context 'by default' do
      it 'creates necessary env variable files' do
        expect(chef_run).to create_env_dir('/opt/gitlab/etc/gitlab-rails/env').with_variables(default_vars)
      end

      context 'when a custom env variable is specified' do
        before do
          stub_gitlab_rb(gitlab_rails: { env: { 'IAM' => 'CUSTOMVAR' } })
        end

        it 'creates necessary env variable files' do
          expect(chef_run).to create_env_dir('/opt/gitlab/etc/gitlab-rails/env').with_variables(
            default_vars.merge(
              {
                'IAM' => 'CUSTOMVAR'
              }
            )
          )
        end
      end
    end

    context 'when relative URL is enabled' do
      before do
        stub_gitlab_rb(gitlab_rails: { gitlab_relative_url: '/gitlab' })
      end

      it 'creates necessary env variable files' do
        expect(chef_run).to create_env_dir('/opt/gitlab/etc/gitlab-rails/env').with_variables(
          default_vars.merge(
            {
              'RAILS_RELATIVE_URL_ROOT' => '/gitlab'
            }
          )
        )
      end
    end

    context 'when relative URL is specified in external_url' do
      before do
        stub_gitlab_rb(external_url: 'http://localhost/gitlab')
      end

      it 'creates necessary env variable files' do
        expect(chef_run).to create_env_dir('/opt/gitlab/etc/gitlab-rails/env').with_variables(
          default_vars.merge(
            {
              'RAILS_RELATIVE_URL_ROOT' => '/gitlab'
            }
          )
        )
      end
    end

    context 'when jemalloc is disabled' do
      before do
        stub_gitlab_rb(gitlab_rails: { enable_jemalloc: false })
      end

      it 'creates necessary env variable files' do
        vars = default_vars.dup
        vars.delete("LD_PRELOAD")
        expect(chef_run).to create_env_dir('/opt/gitlab/etc/gitlab-rails/env').with_variables(vars)
      end
    end
  end

  describe "with symlinked templates" do
    let(:chef_run) { ChefSpec::SoloRunner.new.converge('gitlab::default') }

    before do
      %w(
        alertmanager
        gitlab-monitor
        gitlab-pages
        gitlab-workhorse
        logrotate
        nginx
        node-exporter
        postgres-exporter
        postgresql
        prometheus
        redis
        redis-exporter
        sidekiq
        unicorn
        gitaly
      ).map { |svc| stub_should_notify?(svc, true) }
    end

    describe 'database.yml' do
      let(:templatesymlink) { chef_run.templatesymlink('Create a database.yml and create a symlink to Rails root') }

      context 'by default' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new.converge('gitlab::default')
        end

        it 'creates the template' do
          expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
            hash_including(
              'db_host' => '/var/opt/gitlab/postgresql',
              'db_database' => 'gitlabhq_production',
              'db_load_balancing' => { 'hosts' => [] },
              'db_prepared_statements' => false,
              'db_sslcompression' => 0,
              'db_fdw' => nil
            )
          )
        end

        it 'template triggers notifications' do
          expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
          expect(templatesymlink).not_to notify('service[gitlab-workhorse]').to(:restart).delayed
          expect(templatesymlink).not_to notify('service[nginx]').to(:restart).delayed
        end
      end

      context 'with specific database settings' do
        context 'when multiple postgresql listen_address is used' do
          before do
            stub_gitlab_rb(postgresql: { listen_address: "127.0.0.1,1.1.1.1" })
          end

          it 'creates the postgres configuration file with multi listen_address and database.yml file with one host' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_host' => '127.0.0.1'
              )
            )
            expect(chef_run).to render_file('/var/opt/gitlab/postgresql/data/postgresql.conf').with_content(/listen_addresses = '127.0.0.1,1.1.1.1'/)
          end
        end

        context 'when no postgresql listen_address is used' do
          it 'creates the postgres configuration file with empty listen_address and database.yml file with default one' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_host' => '/var/opt/gitlab/postgresql'
              )
            )
            expect(chef_run).to render_file('/var/opt/gitlab/postgresql/data/postgresql.conf').with_content(/listen_addresses = ''/)
          end
        end

        context 'when one postgresql listen_address is used' do
          cached(:chef_run) do
            RSpec::Mocks.with_temporary_scope do
              stub_gitlab_rb(postgresql: { listen_address: "127.0.0.1" })
            end

            ChefSpec::SoloRunner.new.converge('gitlab::default')
          end

          it 'creates the postgres configuration file with one listen_address and database.yml file with one host' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_host' => '127.0.0.1'
              )
            )
            expect(chef_run).to render_file('/var/opt/gitlab/postgresql/data/postgresql.conf').with_content(/listen_addresses = '127.0.0.1'/)
          end

          it 'template triggers notifications' do
            expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
            expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
            expect(templatesymlink).not_to notify('service[gitlab-workhorse]').to(:restart).delayed
            expect(templatesymlink).not_to notify('service[nginx]').to(:restart).delayed
          end
        end

        context 'when load balancers are specified' do
          before do
            stub_gitlab_rb(gitlab_rails: { db_load_balancing: { 'hosts' => ['primary.example.com', 'secondary.example.com'] } })
          end

          it 'uses provided value in database.yml' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_load_balancing' => { 'hosts' => ['primary.example.com', 'secondary.example.com'] }
              )
            )
          end
        end

        context 'when prepared_statements are disabled' do
          before do
            stub_gitlab_rb(gitlab_rails: { db_prepared_statements: false })
          end

          it 'uses provided value in database.yml' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_prepared_statements' => false,
                'db_statements_limit' => 1000
              )
            )
          end
        end

        context 'when limit for prepared_statements are specified' do
          before do
            stub_gitlab_rb(gitlab_rails: { db_statements_limit: 12345 })
          end

          it 'uses provided value in database.yml' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_prepared_statements' => false,
                'db_statements_limit' => 12345
              )
            )
          end
        end

        context 'when SSL compression is enabled' do
          before do
            stub_gitlab_rb(gitlab_rails: { db_sslcompression: 1 })
          end

          it 'uses provided value in database.yml' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_sslcompression' => 1
              )
            )
          end
        end

        context 'when fdw is specified' do
          before do
            stub_gitlab_rb(gitlab_rails: { db_fdw: true })
          end

          it 'uses provided value in database.yml' do
            expect(chef_run).to create_templatesymlink('Create a database.yml and create a symlink to Rails root').with_variables(
              hash_including(
                'db_fdw' => true
              )
            )
          end
        end
      end
    end

    describe 'gitlab_workhorse_secret' do
      let(:templatesymlink) { chef_run.templatesymlink('Create a gitlab_workhorse_secret and create a symlink to Rails root') }

      context 'by default' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new.converge('gitlab::default')
        end

        it 'creates the template' do
          expect(chef_run).to create_templatesymlink("Create a gitlab_workhorse_secret and create a symlink to Rails root").with(
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        end

        it 'template triggers notifications' do
          expect(templatesymlink).to notify('service[gitlab-workhorse]').to(:restart).delayed
          expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
        end
      end

      context 'with specific gitlab_workhorse_secret' do
        cached(:chef_run) do
          RSpec::Mocks.with_temporary_scope do
            stub_gitlab_rb(gitlab_workhorse: { secret_token: 'abc123-gitlab-workhorse' })
          end

          ChefSpec::SoloRunner.new.converge('gitlab::default')
        end

        it 'renders the correct node attribute' do
          expect(chef_run).to create_templatesymlink("Create a gitlab_workhorse_secret and create a symlink to Rails root").with_variables(
            secret_token: 'abc123-gitlab-workhorse'
          )
        end

        it 'uses the correct owner and permissions' do
          expect(chef_run).to create_templatesymlink('Create a gitlab_workhorse_secret and create a symlink to Rails root').with(
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        end

        it 'template triggers notifications' do
          expect(templatesymlink).to notify('service[gitlab-workhorse]').to(:restart).delayed
          expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
        end
      end
    end

    describe 'gitlab_pages_secret' do
      let(:templatesymlink) { chef_run.templatesymlink('Create a gitlab_pages_secret and create a symlink to Rails root') }
      let(:pages_secret_path) { '/var/opt/gitlab/gitlab-rails/etc/gitlab_pages_secret' }

      context 'by default' do
        cached(:chef_run) do
          RSpec::Mocks.with_temporary_scope do
            stub_gitlab_rb(
              external_url: 'http://gitlab.example.com',
              pages_external_url: 'http://pages.example.com'
            )
          end

          ChefSpec::SoloRunner.new.converge('gitlab::default')
        end

        it 'creates the template' do
          expect(chef_run).to create_templatesymlink('Create a gitlab_pages_secret and create a symlink to Rails root').with(
            owner: 'root',
            group: 'git',
            mode: '0640'
          )
        end

        it 'template triggers notifications' do
          expect(templatesymlink).to notify('service[gitlab-pages]').to(:restart).delayed
          expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
        end
      end

      context 'with specific gitlab_pages_secret' do
        cached(:chef_run) do
          RSpec::Mocks.with_temporary_scope do
            stub_gitlab_rb(
              external_url: 'http://gitlab.example.com',
              pages_external_url: 'http://pages.example.com',
              gitlab_pages: {
                admin_secret_token: 'abc123-gitlab-pages'
              }
            )
          end

          ChefSpec::SoloRunner.new.converge('gitlab::default')
        end

        it 'renders the correct node attribute' do
          expect(chef_run).to create_templatesymlink("Create a gitlab_pages_secret and create a symlink to Rails root").with(
            variables: {
              secret_token: 'abc123-gitlab-pages'
            },
            owner: 'root',
            group: 'git',
            mode: '0640'
          )
        end

        it 'template triggers notifications' do
          expect(templatesymlink).to notify('service[gitlab-pages]').to(:restart).delayed
          expect(templatesymlink).to notify('service[unicorn]').to(:restart).delayed
          expect(templatesymlink).to notify('service[sidekiq]').to(:restart).delayed
        end
      end
    end
  end

  context 'gitlab registry' do
    describe 'registry is disabled' do
      it 'does not generate gitlab-registry.key file' do
        expect(chef_run).not_to render_file("/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key")
      end
    end

    describe 'registry is enabled' do
      before do
        stub_gitlab_rb(
          gitlab_rails: {
            registry_enabled: true
          }
        )
      end

      it 'generates gitlab-registry.key file' do
        expect(chef_run).to render_file("/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key").with_content(/\A-----BEGIN RSA PRIVATE KEY-----\n.+\n-----END RSA PRIVATE KEY-----\n\Z/m)
      end
    end
  end
end
