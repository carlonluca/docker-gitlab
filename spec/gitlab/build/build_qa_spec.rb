require_relative '../../../lib/gitlab/build/qa.rb'
require 'chef_helper'

describe Build::QA do
  describe 'clone gitlab repo' do
    it 'calls the git command' do
      allow(Build::Info).to receive(:package).and_return("gitlab-ee")
      expect(described_class).to receive("system").with("git clone git@dev.gitlab.org:gitlab/gitlab-ee.git /tmp/gitlab.#{$PROCESS_ID}")
      Build::QA.clone_gitlab_rails
    end
  end

  describe 'checkout gitlab repo' do
    it 'calls the git command' do
      allow(Build::Info).to receive(:package).and_return("gitlab-ee")
      allow(Build::Info).to receive(:gitlab_version).and_return("9.0.0")
      expect(described_class).to receive("system").with("git --git-dir=/tmp/gitlab.#{$PROCESS_ID}/.git --work-tree=/tmp/gitlab.#{$PROCESS_ID} checkout --quiet 9.0.0")
      Build::QA.checkout_gitlab_rails
    end
  end

  describe 'get_gitlab_repo' do
    it 'returns correct location' do
      allow(Build::QA).to receive(:clone_gitlab_rails).and_return(true)
      allow(Build::QA).to receive(:checkout_gitlab_rails).and_return(true)
      expect(described_class.get_gitlab_repo).to eq("/tmp/gitlab.#{$PROCESS_ID}/qa")
    end
  end
end
