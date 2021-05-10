require 'docker'
require_relative '../docker_operations'
require_relative '../build/info'
require_relative '../build/check'
require_relative '../build/gitlab_image'
require_relative "../util.rb"

namespace :docker do
  namespace :build do
    desc "Build Docker All in one image"
    task :image do
      Gitlab::Util.section('docker:build:image') do
        Build::GitlabImage.write_release_file
        location = File.absolute_path(File.join(File.dirname(File.expand_path(__FILE__)), "../../../docker"))
        DockerOperations.build(
          location,
          Build::GitlabImage.gitlab_registry_image_address,
          'latest'
        )
      end
    end
  end

  desc "Push Docker Image to Registry"
  namespace :push do
    # Only runs on dev.gitlab.org
    task :staging do
      Gitlab::Util.section('docker:push:staging') do
        Build::GitlabImage.tag_and_push_to_gitlab_registry(Build::Info.docker_tag)
      end
    end

    task :stable do
      Gitlab::Util.section('docker:push:stable') do
        Build::GitlabImage.tag_and_push_to_dockerhub(Build::Info.docker_tag)
      end
    end

    # Special tags
    task :nightly do
      Gitlab::Util.section('docker:push:nightly') do
        Build::GitlabImage.tag_and_push_to_dockerhub('nightly') if Build::Check.is_nightly?
      end
    end

    # push as :rc tag, the :rc is always the latest tagged release
    task :rc do
      Gitlab::Util.section('docker:push:rc') do
        Build::GitlabImage.tag_and_push_to_dockerhub('rc') if Build::Check.is_latest_tag?
      end
    end

    # push as :latest tag, the :latest is always the latest stable release
    task :latest do
      Gitlab::Util.section('docker:push:latest') do
        Build::GitlabImage.tag_and_push_to_dockerhub('latest') if Build::Check.is_latest_stable_tag?
      end
    end

    desc "Push triggered Docker Image to GitLab Registry"
    task :triggered do
      Gitlab::Util.section('docker:push:triggered') do
        Build::GitlabImage.tag_and_push_to_gitlab_registry(Build::Info.docker_tag)
      end
    end
  end

  desc "Pull Docker Image from Registry"
  namespace :pull do
    task :staging do
      Gitlab::Util.section('docker:pull:staging') do
        DockerOperations.authenticate("gitlab-ci-token", Gitlab::Util.get_env("CI_JOB_TOKEN"), Gitlab::Util.get_env('CI_REGISTRY'))
        Build::GitlabImage.pull
      end
    end
  end
end
