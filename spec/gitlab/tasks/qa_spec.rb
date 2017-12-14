require 'chef_helper'

describe 'qa', type: :rake do
  let(:gitlab_registry_image_address) { 'dev.gitlab.org:5005/gitlab/omnibus-gitlab/gitlab-ce-qa' }
  let(:gitlab_version) { '10.2.0' }
  let(:image_tag) { 'omnibus-12345' }

  before(:all) do
    Rake.application.rake_require 'gitlab/tasks/qa'
  end

  describe 'qa:build' do
    before do
      Rake::Task['qa:build'].reenable

      allow(Build::QA).to receive(:get_gitlab_repo).and_return("/tmp/gitlab.1234/qa")
      allow(Build::QAImage).to receive(:gitlab_registry_image_address).and_return(gitlab_registry_image_address)
    end

    it 'calls build method with correct parameters' do
      expect(DockerOperations).to receive(:build).with('/tmp/gitlab.1234/qa', 'dev.gitlab.org:5005/gitlab/omnibus-gitlab/gitlab-ce-qa', 'latest')

      Rake::Task['qa:build'].invoke
    end
  end

  describe 'qa:push' do
    before do
      Rake::Task['qa:push:stable'].reenable
      Rake::Task['qa:push:nightly'].reenable
      Rake::Task['qa:push:rc'].reenable
      Rake::Task['qa:push:latest'].reenable

      allow(Build::Info).to receive(:gitlab_version).and_return(gitlab_version)
    end

    it 'pushes stable images correctly' do
      expect(Build::QAImage).to receive(:tag_and_push_to_gitlab_registry).with(gitlab_version)
      expect(Build::QAImage).to receive(:tag_and_push_to_dockerhub).with(gitlab_version)

      Rake::Task['qa:push:stable'].invoke
    end

    it 'pushes nightly images correctly' do
      expect(Build::Check).to receive(:add_nightly_tag?).and_return(true)

      expect(Build::QAImage).to receive(:tag_and_push_to_dockerhub).with('nightly', initial_tag: 'latest')

      Rake::Task['qa:push:nightly'].invoke
    end

    it 'pushes latest images correctly' do
      expect(Build::Check).to receive(:add_latest_tag?).and_return(true)

      expect(Build::QAImage).to receive(:tag_and_push_to_dockerhub).with('latest', initial_tag: 'latest')

      Rake::Task['qa:push:latest'].invoke
    end

    it 'pushes rc images correctly' do
      expect(Build::Check).to receive(:add_rc_tag?).and_return(true)

      expect(Build::QAImage).to receive(:tag_and_push_to_dockerhub).with('rc', initial_tag: 'latest')

      Rake::Task['qa:push:rc'].invoke
    end

    it 'pushes triggered images correctly' do
      expect(ENV).to receive(:[]).with('IMAGE_TAG').and_return(image_tag)

      expect(Build::QAImage).to receive(:tag_and_push_to_gitlab_registry).with(image_tag)

      Rake::Task['qa:push:triggered'].invoke
    end
  end

  describe 'qa:test' do
    let(:qatrigger) { Build::QATrigger.new }
    let(:qapipeline) { Build::QAPipeline.new(1) }
    before do
      Rake::Task['qa:build'].reenable
      Rake::Task['qa:push:triggered'].reenable
      Rake::Task['qa:test'].reenable

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('QA_TRIGGER_TOKEN').and_return("1234")
      allow(ENV).to receive(:[]).with('TRIGGERED_USER').and_return("John Doe")
      allow(ENV).to receive(:[]).with('CI_JOB_ID').and_return("12345")
      allow(ENV).to receive(:[]).with('IMAGE_TAG').and_return(image_tag)
      allow(DockerOperations).to receive(:build).and_return(true)
      allow(Build::QA).to receive(:get_gitlab_repo).and_return("/tmp/gitlab.1234/qa")
      allow(Build::GitlabImage).to receive(:gitlab_registry_image_address).and_return("registry.gitlab.com/gitlab-ce:latest")
      allow(Build::GitlabImage).to receive(:tag_and_push_to_gitlab_registry).and_return(true)
      allow(Build::QAImage).to receive(:gitlab_registry_image_address).and_return(gitlab_registry_image_address)
      allow(Build::QAImage).to receive(:tag_and_push_to_gitlab_registry).and_return(true)
      allow(Build::QATrigger).to receive(:new).and_return(qatrigger)
      allow_any_instance_of(Build::QAPipeline).to receive(:timeout?).and_return(false)
      allow_any_instance_of(Build::QATrigger).to receive(:invoke!).and_return(qapipeline)
    end

    it 'triggers QA pipeline correcty' do
      class FakeResponse
        attr_reader :body
        def initialize
          @body = "{\"id\": \"1\"}"
        end
      end
      allow(Net::HTTP).to receive(:post_form).and_return(FakeResponse.new)
      allow_any_instance_of(Build::QATrigger).to receive(:invoke!).and_call_original
      allow(Build::QATrigger).to receive(:new).and_call_original
      stub_const("Build::QATrigger::TOKEN", "1234")
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:success)

      uri = URI("https://gitlab.com/api/v4/projects/gitlab-org%2Fgitlab-qa/trigger/pipeline")
      params = {
        "ref" => "master",
        "token" => "1234",
        "variables[RELEASE]" => "registry.gitlab.com/gitlab-ce:latest",
        "variables[TRIGGERED_USER]" => "John Doe",
        "variables[TRIGGER_SOURCE]" => "https://gitlab.com/gitlab-org/omnibus-gitlab/-/jobs/12345"
      }
      expect(Net::HTTP).to receive(:post_form).with(uri, params)
      Rake::Task['qa:test'].invoke
    end

    it 'detects created pipeline' do
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:created, :success)

      expect_any_instance_of(Build::QAPipeline).to receive(:sleep)
      Rake::Task['qa:test'].invoke
      expect { Rake::Task['qa:test'].invoke }.not_to raise_error
    end

    it 'detects pending pipeline' do
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:pending, :success)

      expect_any_instance_of(Build::QAPipeline).to receive(:sleep)
      Rake::Task['qa:test'].invoke
      expect { Rake::Task['qa:test'].invoke }.not_to raise_error
    end

    it 'detects running pipeline' do
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:running, :success)

      expect_any_instance_of(Build::QAPipeline).to receive(:sleep)
      Rake::Task['qa:test'].invoke
      expect { Rake::Task['qa:test'].invoke }.not_to raise_error
    end

    it 'detects successful pipeline' do
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:success)

      expect { Rake::Task['qa:test'].invoke }.not_to raise_error
    end

    it 'detects failed pipeline' do
      allow_any_instance_of(Build::QAPipeline).to receive(:status).and_return(:failed)

      expect { Rake::Task['qa:test'].invoke }.to raise_error(RuntimeError, "QA pipeline did not succeed!")
    end

    it 'times out correctly' do
      allow_any_instance_of(Build::QAPipeline).to receive(:timeout?).and_return(true)
      allow_any_instance_of(Build::QAPipeline).to receive(:duration).and_return(10)

      expect { Rake::Task['qa:test'].invoke }.to raise_error(RuntimeError, "Pipeline timed out after waiting for 10 minutes!")
    end
  end
end
