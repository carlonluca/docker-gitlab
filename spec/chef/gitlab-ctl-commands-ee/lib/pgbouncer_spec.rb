require 'spec_helper'

$LOAD_PATH << File.join(__dir__, '../../../files/gitlab-ctl-commands-ee/lib')

require 'pgbouncer'

RSpec.describe Pgbouncer::Databases do
  let(:fake_ohai) do
    {
      'gitlab' => {
        'gitlab_rails' => {
          'db_database' => 'fake_database',
          'databases' => {
            'main' => 'fake_database',
            'ci' => 'fake_database_ci'
          },
        },
      },
      'pgbouncer' => {
        'databases_ini' => '/fakedata/pgbouncer/databases.ini',
        'databases_json' => '/fakedata/pgbouncer/databases.json'
      }
    }
  end

  let(:fake_databases_json) do
    {
      fakedb: {
        host: 'fakehost',
        user: 'fakeuser',
        port: 9999,
        password: 'dslgkjdfgklfsd'
      }
    }.to_json.to_s
  end

  before do
    allow(GitlabCtl::Util).to receive(:get_fqdn).and_return('fakehost')
    allow(Dir).to receive(:exist?).and_call_original
    allow(Dir).to receive(:exist?).with('/fakedata/pgbouncer').and_return(true)
    allow(File).to receive(:exist?).with('/fakedata/pgbouncer/databases.json').and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(GitlabCtl::Util).to receive(:get_public_node_attributes).and_return(fake_ohai)
    allow(File).to receive(:read).with('/fakedata/pgbouncer/databases.json').and_return(fake_databases_json)
    @obj = Pgbouncer::Databases.new({}, '/fakeinstall', '/fakedata')
  end

  context 'default behavior' do
    it 'allows creating a new object' do
      expect(@obj.class).to be(Pgbouncer::Databases)
    end

    it 'creates the database object' do
      results = {
        "fakedb" => "host=fakehost port=9999 auth_user=fakeuser"
      }
      expect(@obj.databases).to eq(results)
    end

    it 'renders the template' do
      expect(@obj.render).to eq(
        "[databases]\n\nfakedb = host=fakehost port=9999 auth_user=fakeuser\n\n"
      )
    end
  end

  context 'with options' do
    before do
      options = {
        'databases_ini' => '/another/databases.ini',
        'databases_json' => '/another/databases.json',
        'port' => 8888,
        'user' => 'fakeuser',
        'database' => 'fakedb'
      }
      allow(File).to receive(:exist?).with('/another/databases.json').and_return(true)
      allow(File).to receive(:read).with('/another/databases.json').and_return(fake_databases_json)
      @obj = Pgbouncer::Databases.new(options, '/fakeinstall', '/fakedata')
    end

    it 'sets the custom options' do
      expect(@obj.ini_file).to eq('/another/databases.ini')
      expect(@obj.json_file).to eq('/another/databases.json')
    end

    it 'renders the template' do
      expect(@obj.render).to eq(
        "[databases]\n\nfakedb = host=fakehost port=8888 auth_user=fakeuser\n\n"
      )
    end
  end

  context 'with empty databases.json' do
    before do
      allow(File).to receive(:read).with('/fakedata/pgbouncer/databases.json').and_return({}.to_s)
      @obj = Pgbouncer::Databases.new({}, '/fakeinstall', '/fakedata')
    end

    it 'should generate an databases.ini with the default rails database' do
      expect(@obj.render).to eq(
        "[databases]\n\nfake_database = dbname=fake_database\n\nfake_database_ci = dbname=fake_database_ci\n\n"
      )
    end
  end

  context 'with pgbouncer listening' do
    before do
      allow(@obj).to receive(:show_databases).and_return("nyan")
    end

    it 'should be running' do
      expect(@obj.running?).to be true
    end
  end

  context 'with pgbouncer not listening' do
    before do
      allow(@obj).to receive(:show_databases).and_raise(GitlabCtl::Errors::ExecutionError.new("nya", "nya", "neko"))
    end

    it 'should not be running' do
      expect(@obj.running?).to be false
    end
  end
end
