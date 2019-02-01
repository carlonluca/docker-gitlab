require_relative 'trigger'
require_relative "../util.rb"

module Build
  class QATrigger
    extend Trigger

    QA_PROJECT_PATH = 'gitlab-org/gitlab-qa'.freeze

    def self.get_project_path
      QA_PROJECT_PATH
    end

    def self.get_params(image: nil)
      {
        "ref" => Gitlab::Util.get_env('QA_BRANCH') || 'master',
        "token" => Gitlab::Util.get_env('QA_TRIGGER_TOKEN'),
        "variables[RELEASE]" => image,
        "variables[TRIGGERED_USER]" => Gitlab::Util.get_env("TRIGGERED_USER") || Gitlab::Util.get_env("GITLAB_USER_NAME"),
        "variables[TRIGGER_SOURCE]" => Gitlab::Util.get_env('CI_JOB_URL'),
        "variables[TOP_UPSTREAM_SOURCE_PROJECT]" => Gitlab::Util.get_env('TOP_UPSTREAM_SOURCE_PROJECT'),
        "variables[TOP_UPSTREAM_SOURCE_JOB]" => Gitlab::Util.get_env('TOP_UPSTREAM_SOURCE_JOB'),
        "variables[TOP_UPSTREAM_SOURCE_SHA]" => Gitlab::Util.get_env('TOP_UPSTREAM_SOURCE_SHA')
      }
    end

    def self.get_access_token
      Gitlab::Util.get_env('GITLAB_BOT_MULTI_PROJECT_PIPELINE_POLLING_TOKEN')
    end
  end
end
