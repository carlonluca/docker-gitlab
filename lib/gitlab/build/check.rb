require_relative "info.rb"
require_relative "../util.rb"

module Build
  class Check
    AUTO_DEPLOY_TAG_REGEX_CAPTURE = /^(?<major>\d+)\.(?<minor>\d+)\.(?<pipeline_id>[^ ]+)\+(?<shas>[^ ]+)$/
    class << self
      def is_ee?
        Gitlab::Util.get_env('ee') == 'true' || \
          Gitlab::Util.get_env('GITLAB_VERSION')&.end_with?('-ee') || \
          File.read('VERSION').strip.end_with?('-ee') || \
          is_auto_deploy?
      end

      def match_tag?(tag)
        system(*%W[git describe --exact-match --match #{tag}])
      end

      def is_auto_deploy?
        AUTO_DEPLOY_TAG_REGEX_CAPTURE.match?(git_exact_match)
      end

      def auto_deploy_match
        AUTO_DEPLOY_TAG_REGEX_CAPTURE.match(git_exact_match)
      end

      def is_patch_release?
        # Major and minor releases have patch component as zero
        Info.semver_version.split(".")[-1] != "0"
      end

      def is_rc_release?
        git_exact_match.include?("+rc")
      end

      def add_latest_tag?
        match_tag?(Info.latest_stable_tag)
      end

      def add_rc_tag?
        match_tag?(Info.latest_tag)
      end

      def add_nightly_tag?
        Gitlab::Util.get_env('NIGHTLY') == 'true'
      end

      def no_changes?
        system(*%w[git diff --quiet])
      end

      def on_tag?
        system(*%w[git describe --exact-match])
      end

      def git_exact_match
        `git describe --exact-match`
      end
    end
  end
end
