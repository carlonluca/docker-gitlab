require 'chef_helper'

describe 'gitlab::unicorn' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(
      step_into: %w(templatesymlink),
      path: 'spec/fixtures/fauxhai/ubuntu/16.04.json'
    )
    runner.converge('gitlab::default')
  end

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when unicorn is enabled' do
    it_behaves_like 'enabled runit service', 'unicorn', 'root', 'root'

    it 'populates the files with expected configuration' do
      expect(chef_run).to render_file('/opt/gitlab/sv/unicorn/run')
        .with_content { |content|
          expect(content).not_to match(/export prometheus_run_dir=\'\'/)
          expect(content).to match(/mkdir -p \/run\/gitlab\/unicorn/)
          expect(content).to match(/rm \/run\/gitlab\/unicorn/)
          expect(content).to match(/chmod 0600 \/run\/gitlab\/unicorn/)
          expect(content).to match(/chown git \/run\/gitlab\/unicorn/)
          expect(content).to match(/export prometheus_run_dir=\'\/run\/gitlab\/unicorn\'/)
        }
    end
  end
end

describe 'gitlab::unicorn' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(
      step_into: %w(templatesymlink),
      path: 'spec/fixtures/fauxhai/ubuntu/16.04-no-run-tmpfs.json'
    )
    runner.converge('gitlab::default')
  end

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when unicorn is enabled on a node with no /run tmpfs' do
    it_behaves_like 'enabled runit service', 'unicorn', 'root', 'root'

    it 'populates the files with expected configuration' do
      expect(chef_run).to render_file('/opt/gitlab/sv/unicorn/run')
        .with_content { |content|
          expect(content).to match(/export prometheus_run_dir=\'\'/)
          expect(content).not_to match(/mkdir -p \/run\/gitlab\/unicorn/)
        }
    end
  end
end
