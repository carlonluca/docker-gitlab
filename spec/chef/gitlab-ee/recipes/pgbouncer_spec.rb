#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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
require 'chef_helper'

describe 'gitlab-ee::pgbouncer' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab-ee::default') }
  let(:pgbouncer_ini) { '/var/opt/gitlab/pgbouncer/pgbouncer.ini' }
  let(:databases_json) { '/var/opt/gitlab/pgbouncer/databases.json' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  describe 'when enabled' do
    before do
      stub_gitlab_rb(
        pgbouncer: {
          enable: true,
          databases: {
            gitlabhq_production: {
              host: '1.2.3.4'
            }
          }
        },
        postgresql: {
          pgbouncer_user: 'fakeuser',
          pgbouncer_user_password: 'fakeuserpassword'
        }
      )
    end

    it 'includes the pgbouncer recipe' do
      expect(chef_run).to include_recipe('gitlab-ee::pgbouncer')
    end

    it 'includes the postgresql user recipe' do
      expect(chef_run).to include_recipe('gitlab::postgresql_user')
    end

    it_behaves_like 'enabled runit service', 'pgbouncer', 'root', 'root'

    it 'creates the appropriate directories' do
      expect(chef_run).to create_directory('/var/log/gitlab/pgbouncer')
      expect(chef_run).to create_directory('/var/opt/gitlab/pgbouncer')
    end

    it 'installs pgbouncer.ini with default values' do
      # Default values are pulled from:
      # https://github.com/pgbouncer/pgbouncer/blob/6ef66f0139b9c8a5c0747f2a6157d008b87bf0c5/etc/pgbouncer.ini
      expect(chef_run).to render_file(pgbouncer_ini).with_content { |content|
        expect(content).to match(%r{^logfile = /var/log/gitlab/pgbouncer/pgbouncer\.log$})
        expect(content).to match(%r{^pidfile = /var/opt/gitlab/pgbouncer/pgbouncer\.pid$})
        expect(content).to match(/^listen_addr = 0\.0\.0\.0$/)
        expect(content).to match(/^listen_port = 6432$/)
        expect(content).to match(/^pool_mode = session$/)
        expect(content).to match(/^server_reset_query = DISCARD ALL$/)
        expect(content).to match(/^max_client_conn = 100$/)
        expect(content).to match(/^default_pool_size = 20$/)
        expect(content).to match(/^min_pool_size = 0$/)
        expect(content).to match(/^reserve_pool_size = 0$/)
        expect(content).to match(/^reserve_pool_timeout = 5.0$/)
        expect(content).to match(/^server_round_robin = 0$/)
        expect(content).to match(/^auth_type = md5$/)
        expect(content).to match(/^log_connections = 0/)
        expect(content).to match(/^server_idle_timeout = 600.0$/)
        expect(content).to match(/^dns_max_ttl = 15.0$/)
        expect(content).to match(/^dns_zone_check_period = 0$/)
        expect(content).to match(/^dns_nxdomain_ttl = 15.0$/)
        expect(content).to match(%r{^auth_file = /var/opt/gitlab/pgbouncer/pg_auth$})
        expect(content).to match(/^admin_users = gitlab-psql, postgres, pgbouncer$/)
        expect(content).to match(/^stats_users = gitlab-psql, postgres, pgbouncer$/)
        expect(content).to match(/^ignore_startup_parameters = extra_float_digits$/)
        expect(content).to match(%r{^%include /var/opt/gitlab/pgbouncer/databases.ini})
      }
    end

    context 'pgbouncer.ini template changes' do
      let(:template) { chef_run.template(pgbouncer_ini) }

      it 'reloads pgbouncer if pgbouncer is already running' do
        allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).and_call_original
        allow_any_instance_of(OmnibusHelper).to receive(:should_notify?).with('pgbouncer').and_return(true)
        expect(template).to notify('execute[reload pgbouncer]').to(:run).immediately
      end
    end

    context 'databases.json' do
      it 'creates databases.json' do
        expect(chef_run).to create_file(databases_json)
          .with_content("{\"gitlabhq_production\":{\"host\":\"1.2.3.4\"}}")
          .with(user: 'gitlab-psql', group: 'gitlab-psql')
      end

      it 'notifies pgb-notify to generate databases.ini' do
        json_resource = chef_run.file(databases_json)
        expect(json_resource).to notify('execute[generate databases.ini]').to(:run).immediately
      end

      it 'stores in a different location when attribute is set' do
        stub_gitlab_rb(
          pgbouncer: {
            enable: true,
            databases_json: '/fakepath/fakedatabases.json'
          }
        )
        expect(chef_run).to create_file('databases.json')
          .with(path: '/fakepath/fakedatabases.json')
      end

      it 'changes the user when the attribute is changed' do
        stub_gitlab_rb(
          pgbouncer: {
            enable: true,
            databases_ini_user: 'fakeuser'
          }
        )
        expect(chef_run).to create_file('databases.json')
          .with(user: 'fakeuser', group: 'fakeuser')
      end
    end
  end

  it 'sets up auth_hba when attributes are set' do
    stub_gitlab_rb(
      {
        pgbouncer: {
          enable: true,
          auth_hba_file: '/fake/hba_file',
          auth_query: 'SELECT * FROM FAKETABLE'
        }
      }
    )
    expect(chef_run).to render_file(pgbouncer_ini).with_content { |content|
      expect(content).to match(%r{^auth_hba_file = /fake/hba_file$})
      expect(content).to match(/^auth_query = SELECT \* FROM FAKETABLE$/)
    }
  end

  it 'does not create the user file by default' do
    expect(chef_run).not_to render_file('/var/opt/gitlab/pgbouncer/pg_auth')
  end

  it 'creates the user file when the attributes are set' do
    stub_gitlab_rb(
      {
        pgbouncer: {
          enable: true,
          databases: {
            gitlabhq_production: {
              password: 'fakemd5password',
              user: 'fakeuser',
              host: '127.0.0.1',
              port: 5432
            }
          }
        }
      }
    )
    expect(chef_run).to render_file('/var/opt/gitlab/pgbouncer/pg_auth')
      .with_content(%r{^"fakeuser" "md5fakemd5password"$})
  end

  it 'adds arbitrary values to the databases.ini file' do
    stub_gitlab_rb(
      {
        pgbouncer: {
          enable: true,
          databases: {
            gitlab_db: {
              host: 'fakehost',
              fakefield: 'fakedata'
            }
          }
        }
      }
    )
    expect(chef_run).to render_file(databases_ini)
      .with_content(/^gitlab_db = host=fakehost fakefield=fakedata$/)
  end

  it 'creates arbitrary user' do
    stub_gitlab_rb(
      {
        pgbouncer: {
          enable: true,
          users: {
            'fakeuser': {
              'password': 'fakehash'
            }
          }
        }
      }
    )
    expect(chef_run).to render_file('/var/opt/gitlab/pgbouncer/pg_auth')
      .with_content(%r{^"fakeuser" "md5fakehash"})
  end

  context 'when disabled by default' do
    it_behaves_like 'disabled runit service', 'pgbouncer'

    it 'includes the pgbouncer_disable recipe' do
      expect(chef_run).to include_recipe('gitlab-ee::pgbouncer_disable')
    end
  end
end

describe 'gitlab-ee::default' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab-ee::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
    stub_gitlab_rb(
      {
        pgbouncer: {
          db_user_password: 'fakeuserpassword'
        },
        postgresql: {
          pgbouncer_user: 'fakeuser',
          pgbouncer_user_password: 'fakeuserpassword'
        }
      }
    )
  end

  it 'should create the pgbouncer user on the database' do
    expect(chef_run).to include_recipe('gitlab-ee::pgbouncer_user')
  end

  it 'should create the pg_shadow_lookup function on the database' do
    expect(chef_run).to run_execute('Add pgbouncer auth function')
  end
end
