require 'chef_helper'

describe 'postgresql 9.2' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }
  let(:postgresql_conf) { '/var/opt/gitlab/postgresql/data/postgresql.conf' }
  let(:runtime_conf) { '/var/opt/gitlab/postgresql/data/runtime.conf' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
    allow_any_instance_of(PgHelper).to receive(:version).and_return('9.2.18')
    allow_any_instance_of(PgHelper).to receive(:database_version).and_return('9.2')
  end

  it 'includes the postgresql-bin recipe' do
    expect(chef_run).to include_recipe('gitlab::postgresql-bin')
  end

  it 'includes the postgresql_user recipe' do
    expect(chef_run).to include_recipe('gitlab::postgresql_user')
  end

  it_behaves_like 'enabled runit service', 'postgresql', 'root', 'root'

  context 'renders postgresql.conf' do
    it 'includes runtime.conf in postgreslq.conf' do
      expect(chef_run).to render_file(postgresql_conf)
        .with_content(/include 'runtime.conf'/)
    end

    context 'with default settings' do
      it 'correctly sets the shared_preload_libraries default setting' do
        expect(chef_run.node['gitlab']['postgresql']['shared_preload_libraries'])
          .to be_nil

        expect(chef_run).to render_file(postgresql_conf)
          .with_content(/shared_preload_libraries = ''/)
      end

      it 'sets archive settings' do
        expect(chef_run).to render_file(
          postgresql_conf
        ).with_content(/archive_mode = off/)
      end
    end

    context 'when user settings are set' do
      before do
        stub_gitlab_rb(postgresql: {
                         shared_preload_libraries: 'pg_stat_statements',
                         archive_mode: 'on'
                       })
      end

      it 'correctly sets the shared_preload_libraries setting' do
        expect(chef_run.node['gitlab']['postgresql']['shared_preload_libraries'])
          .to eql('pg_stat_statements')

        expect(chef_run).to render_file(postgresql_conf)
          .with_content(/shared_preload_libraries = 'pg_stat_statements'/)
      end

      it 'sets archive settings' do
        expect(chef_run).to render_file(
          postgresql_conf
        ).with_content(/archive_mode = on/)
      end
    end
  end

  context 'renders runtime.conf' do
    context 'with default settings' do
      it 'correctly sets the log_line_prefix default setting' do
        expect(chef_run.node['gitlab']['postgresql']['log_line_prefix'])
          .to be_nil

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/log_line_prefix = ''/)
      end

      it 'sets max_standby settings' do
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/max_standby_archive_delay = 30s/)
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/max_standby_streaming_delay = 30s/)
      end

      it 'sets archive settings' do
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/archive_command = ''/)
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/archive_timeout = 60/)
      end
    end

    context 'when user settings are set' do
      before do
        stub_gitlab_rb(postgresql: {
                         log_line_prefix: '%a',
                         max_standby_archive_delay: '60s',
                         max_standby_streaming_delay: '120s',
                         archive_command: 'command',
                         archive_timeout: '120',
                       })
      end

      it 'correctly sets the log_line_prefix setting' do
        expect(chef_run.node['gitlab']['postgresql']['log_line_prefix'])
          .to eql('%a')

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/log_line_prefix = '%a'/)
      end

      it 'sets max_standby settings' do
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/max_standby_archive_delay = 60s/)
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/max_standby_streaming_delay = 120s/)
      end

      it 'sets archive settings' do
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/archive_command = 'command'/)
        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/archive_timeout = 120/)
      end
    end
  end

  context 'version specific settings' do
    it 'sets unix_socket_directory' do
      expect(chef_run.node['gitlab']['postgresql']['unix_socket_directory'])
        .to eq('/var/opt/gitlab/postgresql')
      expect(chef_run.node['gitlab']['postgresql']['unix_socket_directories'])
        .to eq(nil)
      expect(chef_run).to render_file(
        postgresql_conf
      ).with_content { |content|
        expect(content).to match(
          /unix_socket_directory = '\/var\/opt\/gitlab\/postgresql'/
        )
        expect(content).not_to match(
          /unix_socket_directories = '\/var\/opt\/gitlab\/postgresql'/
        )
      }
    end

    it 'sets checkpoint_segments' do
      expect(chef_run.node['gitlab']['postgresql']['checkpoint_segments'])
        .to eq(10)
      expect(chef_run).to render_file(
        runtime_conf
      ).with_content(/checkpoint_segments = 10/)
    end

    it 'does not set the max_replication_slots setting' do
      expect(chef_run).to render_file(
        postgresql_conf
      ).with_content { |content|
        expect(content).not_to match(/max_replication_slots = /)
      }
    end

    context 'running version differs from data version' do
      before do
        allow_any_instance_of(PgHelper).to receive(:version).and_return('9.6.1')
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("/var/opt/gitlab/postgresql/data/PG_VERSION").and_return(true)
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.2*").and_return(
          ['/opt/gitlab/embedded/postgresql/9.2.18']
        )
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.2.18/bin/*").and_return(
          %w(
            /opt/gitlab/embedded/postgresql/9.2.18/bin/foo_one
            /opt/gitlab/embedded/postgresql/9.2.18/bin/foo_two
            /opt/gitlab/embedded/postgresql/9.2.18/bin/foo_three
          )
        )
      end

      it 'corrects symlinks to the correct location' do
        allow(FileUtils).to receive(:ln_sf).and_return(true)
        %w(foo_one foo_two foo_three).each do |pg_bin|
          expect(FileUtils).to receive(:ln_sf).with(
            "/opt/gitlab/embedded/postgresql/9.2.18/bin/#{pg_bin}",
            "/opt/gitlab/embedded/bin/#{pg_bin}"
          )
        end
        chef_run.ruby_block('Link postgresql bin files to the correct version').old_run_action(:run)
      end
    end
  end
end

describe 'postgresql 9.6' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(sysctl)).converge('gitlab::default') }
  let(:postgresql_conf) { '/var/opt/gitlab/postgresql/data/postgresql.conf' }
  let(:runtime_conf) { '/var/opt/gitlab/postgresql/data/runtime.conf' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
    allow_any_instance_of(PgHelper).to receive(:version).and_return('9.6.1')
    allow_any_instance_of(PgHelper).to receive(:database_version).and_return('9.6')
  end

  context 'version specific settings' do
    it 'sets unix_socket_directories' do
      expect(chef_run.node['gitlab']['postgresql']['unix_socket_directory'])
        .to eq('/var/opt/gitlab/postgresql')
      expect(chef_run).to render_file(
        postgresql_conf
      ).with_content { |content|
        expect(content).to match(
          /unix_socket_directories = '\/var\/opt\/gitlab\/postgresql'/
        )
        expect(content).not_to match(
          /unix_socket_directory = '\/var\/opt\/gitlab\/postgresql'/
        )
      }
    end

    context 'renders postgresql.conf' do
      it 'does not set checkpoint_segments' do
        expect(chef_run).not_to render_file(
          postgresql_conf
        ).with_content(/checkpoint_segments = 10/)
      end

      it 'sets the max_replication_slots setting' do
        expect(chef_run.node['gitlab']['postgresql']['max_replication_slots'])
          .to eq(0)

        expect(chef_run).to render_file(
          postgresql_conf
        ).with_content(/max_replication_slots = 0/)
      end

      it 'sets the synchronous_commit setting' do
        expect(chef_run.node['gitlab']['postgresql']['synchronous_standby_names'])
          .to eq('')

        expect(chef_run).to render_file(
          postgresql_conf
        ).with_content(/synchronous_standby_names = ''/)
      end

      it 'does not set dynamic_shared_memory_type by default' do
        expect(chef_run).not_to render_file(
          postgresql_conf
        ).with_content(/^dynamic_shared_memory_type = /)
      end

      it 'sets the max_locks_per_transaction setting' do
        expect(chef_run.node['gitlab']['postgresql']['max_locks_per_transaction'])
          .to eq(128)

        expect(chef_run).to render_file(
          postgresql_conf
        ).with_content(/max_locks_per_transaction = 128/)
      end

      context 'when dynamic_shared_memory_type is none' do
        before do
          stub_gitlab_rb({
                           postgresql: {
                             dynamic_shared_memory_type: 'none'
                           }
                         })
        end

        it 'sets the dynamic_shared_memory_type' do
          expect(chef_run).to render_file(
            postgresql_conf
          ).with_content(/^dynamic_shared_memory_type = none/)
        end
      end
    end

    context 'renders runtime.conf' do
      it 'sets the synchronous_commit setting' do
        expect(chef_run.node['gitlab']['postgresql']['synchronous_commit'])
          .to eq('on')

        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/synchronous_commit = on/)
      end

      it 'sets the hot_standby_feedback setting' do
        expect(chef_run.node['gitlab']['postgresql']['hot_standby_feedback'])
          .to eq('off')

        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/hot_standby_feedback = off/)
      end

      it 'sets the random_page_cost setting' do
        expect(chef_run.node['gitlab']['postgresql']['random_page_cost'])
          .to eq(2.0)

        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/random_page_cost = 2\.0/)
      end

      it 'sets the log_temp_files setting' do
        expect(chef_run.node['gitlab']['postgresql']['log_temp_files'])
          .to eq(-1)

        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/log_temp_files = -1/)
      end

      it 'sets the log_checkpoints setting' do
        expect(chef_run.node['gitlab']['postgresql']['log_checkpoints'])
          .to eq('off')

        expect(chef_run).to render_file(
          runtime_conf
        ).with_content(/log_checkpoints = off/)
      end

      it 'sets idle_in_transaction_session_timeout' do
        expect(chef_run.node['gitlab']['postgresql']['idle_in_transaction_session_timeout'])
          .to eq('60000')

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/idle_in_transaction_session_timeout = 60000/)
      end

      it 'sets effective_io_concurrency' do
        expect(chef_run.node['gitlab']['postgresql']['effective_io_concurrency'])
          .to eq(1)

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/effective_io_concurrency = 1/)
      end

      it 'sets max_worker_processes' do
        expect(chef_run.node['gitlab']['postgresql']['max_worker_processes'])
          .to eq(8)

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/max_worker_processes = 8/)
      end

      it 'sets max_parallel_workers_per_gather' do
        expect(chef_run.node['gitlab']['postgresql']['max_parallel_workers_per_gather'])
          .to eq(0)

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/max_parallel_workers_per_gather = 0/)
      end

      it 'sets log_lock_waits' do
        expect(chef_run.node['gitlab']['postgresql']['log_lock_waits'])
          .to eq(1)

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/log_lock_waits = 1/)
      end

      it 'sets deadlock_timeout' do
        expect(chef_run.node['gitlab']['postgresql']['deadlock_timeout'])
          .to eq('5s')

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/deadlock_timeout = '5s'/)
      end

      it 'sets track_io_timing' do
        expect(chef_run.node['gitlab']['postgresql']['track_io_timing'])
          .to eq('off')

        expect(chef_run).to render_file(runtime_conf)
          .with_content(/track_io_timing = 'off'/)
      end
    end

    it 'notifies reload postgresql when postgresql.conf changes' do
      allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).and_call_original
      allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).with('postgresql').and_return(true)
      postgresql_config = chef_run.template(postgresql_conf)
      expect(postgresql_config).to notify('execute[reload postgresql]').to(:run).immediately
      expect(postgresql_config).to notify('execute[start postgresql]').to(:run).immediately
    end

    context 'running version differs from data version' do
      before do
        allow_any_instance_of(PgHelper).to receive(:version).and_return('9.2.18')
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("/var/opt/gitlab/postgresql/data/PG_VERSION").and_return(true)
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.6*").and_return(
          ['/opt/gitlab/embedded/postgresql/9.6.1']
        )
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.6.1/bin/*").and_return(
          %w(
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_one
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_two
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_three
          )
        )
      end

      it 'corrects symlinks to the correct location' do
        allow(FileUtils).to receive(:ln_sf).and_return(true)
        %w(foo_one foo_two foo_three).each do |pg_bin|
          expect(FileUtils).to receive(:ln_sf).with(
            "/opt/gitlab/embedded/postgresql/9.6.1/bin/#{pg_bin}",
            "/opt/gitlab/embedded/bin/#{pg_bin}"
          )
        end
        chef_run.ruby_block('Link postgresql bin files to the correct version').old_run_action(:run)
      end
    end

    context 'old unused data version is present' do
      before do
        allow_any_instance_of(PgHelper).to receive(:database_version).and_return('9.2')
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("/var/opt/gitlab/postgresql/data/PG_VERSION").and_return(true)
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.2*").and_return([])
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.6.1*").and_return(
          ['/opt/gitlab/embedded/postgresql/9.6.1']
        )
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.6.1/bin/*").and_return(
          %w(
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_one
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_two
            /opt/gitlab/embedded/postgresql/9.6.1/bin/foo_three
          )
        )
      end

      it 'corrects symlinks to the correct location' do
        allow(FileUtils).to receive(:ln_sf).and_return(true)
        %w(foo_one foo_two foo_three).each do |pg_bin|
          expect(FileUtils).to receive(:ln_sf).with(
            "/opt/gitlab/embedded/postgresql/9.6.1/bin/#{pg_bin}",
            "/opt/gitlab/embedded/bin/#{pg_bin}"
          )
        end
        chef_run.ruby_block('Link postgresql bin files to the correct version').old_run_action(:run)
      end
    end

    context 'the desired postgres version is missing' do
      before do
        allow_any_instance_of(PgHelper).to receive(:database_version).and_return('9.2.18')
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("/var/opt/gitlab/postgresql/data/PG_VERSION").and_return(true)
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.2*").and_return([])
        allow(Dir).to receive(:glob).with("/opt/gitlab/embedded/postgresql/9.6*").and_return([])
      end

      it 'throws an error' do
        expect do
          chef_run.ruby_block('Link postgresql bin files to the correct version').old_run_action(:run)
        end.to raise_error(RuntimeError, /Could not find PostgreSQL binaries/)
      end
    end
  end

  context 'postgresql_user resource' do
    before do
      stub_gitlab_rb(
        {
          postgresql: {
            sql_user_password: 'fakepassword'
          }
        }
      )
    end

    it 'should set a password for sql_user when sql_user_password is set' do
      expect(chef_run).to create_postgresql_user('gitlab').with(password: 'md5fakepassword')
    end

    it 'should create the gitlab_replicator user with replication permissions' do
      expect(chef_run).to create_postgresql_user('gitlab_replicator').with(options: %w(replication))
    end
  end

  context 'pg_hba.conf' do
    let(:pg_hba_conf) { '/var/opt/gitlab/postgresql/data/pg_hba.conf' }
    it 'creates a standard pg_hba.conf' do
      expect(chef_run).to render_file(pg_hba_conf)
        .with_content('local   all         all                               peer map=gitlab')
    end

    it 'adds users custom entries to pg_hba.conf' do
      stub_gitlab_rb(
        postgresql: {
          custom_pg_hba_entries: {
            foo: [
              {
                type: 'host',
                database: 'foo',
                user: 'bar',
                cidr: '127.0.0.1/32',
                method: 'trust'
              }
            ]
          }
        }
      )
      expect(chef_run).to render_file(pg_hba_conf)
        .with_content('host foo bar 127.0.0.1/32 trust')
    end

    it 'notifies postgresql reload' do
      allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).and_call_original
      allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).with('postgresql').and_return(true)
      hba_resource = chef_run.template(pg_hba_conf)
      expect(hba_resource).to notify('execute[reload postgresql]').to(:run).immediately
      expect(hba_resource).to notify('execute[start postgresql]').to(:run).immediately
    end
  end

  it 'creates sysctl files' do
    expect(chef_run).to render_file('/opt/gitlab/embedded/etc/90-omnibus-gitlab-kernel.shmmax.conf').with_content("17179869184")
  end
end
