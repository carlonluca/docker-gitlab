require 'chef_helper'

describe 'gitlab::postgres-exporter' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when postgres-exporter is enabled' do
    let(:config_template) { chef_run.template('/var/log/gitlab/postgres-exporter/config') }

    before do
      stub_gitlab_rb(
        postgres_exporter: { enable: true }
      )
    end

    it_behaves_like 'enabled runit service', 'postgres-exporter', 'root', 'root'

    it 'populates the files with expected configuration' do
      expect(config_template).to notify('ruby_block[reload postgres-exporter svlogd configuration]')

      expect(chef_run).to render_file('/opt/gitlab/sv/postgres-exporter/run')
        .with_content { |content|
          expect(content).to match(/exec chpst /)
          expect(content).to match(/\/opt\/gitlab\/embedded\/bin\/postgres_exporter/)
        }

      expect(chef_run).to render_file('/opt/gitlab/sv/postgres-exporter/log/run')
        .with_content(/exec svlogd -tt \/var\/log\/gitlab\/postgres-exporter/)
    end

    it 'creates default set of directories' do
      expect(chef_run).to create_directory('/var/log/gitlab/postgres-exporter').with(
        owner: 'gitlab-psql',
        group: nil,
        mode: '0700'
      )
    end
  end

  context 'when log dir is changed' do
    before do
      stub_gitlab_rb(
        postgres_exporter: {
          log_directory: 'foo',
          enable: true
        }
      )
    end

    it 'populates the files with expected configuration' do
      expect(chef_run).to render_file('/opt/gitlab/sv/postgres-exporter/log/run')
        .with_content(/exec svlogd -tt foo/)
    end
  end
end
