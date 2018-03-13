require_relative '../../../lib/gitlab/build/metrics'
require 'chef_helper'

describe Build::Metrics do
  before do
    allow_any_instance_of(Kernel).to receive(:system).and_return(true)
  end

  describe '.configure_gitlab_repo' do
    it 'shells out to system correctly' do
      expect_any_instance_of(Kernel).to receive(:system).with(/apt-get update && apt-get install/)
      expect_any_instance_of(Kernel).to receive(:system).with(/curl.*packages.gitlab.com.*gitlab-ee.*|bash/)

      described_class.configure_gitlab_repo
    end
  end

  describe '.install_package' do
    describe 'when upgrade not set' do
      it 'installs gitlab-ee pacakge and runs reconfigure explicitly' do
        expect_any_instance_of(Kernel).to receive(:system).with(/apt-get -y install gitlab-ee=1.2.3/)
        expect_any_instance_of(Kernel).to receive(:system).with(/runsvdir-start/)
        expect_any_instance_of(Kernel).to receive(:system).with(/gitlab-ctl reconfigure/)

        described_class.install_package("1.2.3", upgrade: false)
      end
    end

    describe 'when upgrade set' do
      it 'installs gitlab-ee pacakge but does not run reconfigure explicitly' do
        expect_any_instance_of(Kernel).to receive(:system).with(/apt-get -y install gitlab-ee=1.2.3/)
        expect_any_instance_of(Kernel).not_to receive(:system).with(/runsvdir-start/)
        expect_any_instance_of(Kernel).not_to receive(:system).with(/gitlab-ctl reconfigure/)

        described_class.install_package("1.2.3", upgrade: true)
      end
    end
  end

  describe '.should_upgrade?' do
    before do
      allow(Build::Check).to receive(:is_ee?).and_return(true)
      allow(Build::Check).to receive(:add_latest_tag?).and_return(true)
      allow(Build::Check).to receive(:is_patch_release?).and_return(false)
    end

    it 'detects CE package' do
      allow(Build::Check).to receive(:is_ee?).and_return(false)

      expect(described_class).to receive(:puts).with("Not an EE package. Not upgrading.")
      expect(described_class.should_upgrade?).to be_falsey
    end

    it 'detects patch release' do
      allow(Build::Check).to receive(:is_patch_release?).and_return(true)

      expect(described_class).to receive(:puts).with("Not a major/minor release. Not upgrading.")
      expect(described_class.should_upgrade?).to be_falsey
    end

    it 'detects RC package' do
      allow(Build::Check).to receive(:add_latest_tag?).and_return(false)

      expect(described_class).to receive(:puts).with("Not a latest stable release. Not upgrading.")
      expect(described_class.should_upgrade?).to be_falsey
    end

    it 'detects latest EE release' do
      expect(described_class.should_upgrade?).to be_truthy
    end
  end

  describe '.get_latest_log' do
    it 'extracts last log to preferred location' do
      expect_any_instance_of(Kernel).to receive(:system).with("tac /var/log/apt/term.log | sed '/^Log started/q' | tac > /my/random/path.log")

      described_class.get_latest_log("/my/random/path.log")
    end
  end

  describe '.calculate duration' do
    it 'calculates duration correctly' do
      allow(File).to receive(:open).with("/tmp/upgrade.log").and_return(["Log started: 2018-01-25  15:55:15", "Some random log", "Log ended: 2018-01-25  16:00:05"])
      allow(described_class).to receive(:get_latest_log).and_return(true)

      expect(described_class.calculate_duration).to eq(290)
    end
  end
end
