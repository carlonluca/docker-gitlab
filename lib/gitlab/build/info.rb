require 'omnibus'

require_relative 'info/git'
require_relative '../build_iteration'
require_relative "../util.rb"
require_relative './info/ci'
require_relative 'check'
require_relative 'image'

module Build
  class Info
    DEPLOYER_OS_MAPPING = {
      'AUTO_DEPLOY_ENVIRONMENT' => 'ubuntu-xenial',
      'PATCH_DEPLOY_ENVIRONMENT' => 'ubuntu-bionic',
      'RELEASE_DEPLOY_ENVIRONMENT' => 'ubuntu-focal',
    }.freeze
    PACKAGE_GLOB = "pkg/**/*.{deb,rpm}".freeze

    class << self
      def package
        return "gitlab-fips" if Check.use_system_ssl?
        return "gitlab-ee" if Check.is_ee?

        "gitlab-ce"
      end

      # For auto-deploy builds, we set the semver to the following which is
      # derived directly from the auto-deploy tag:
      #   MAJOR.MINOR.PIPELINE_ID+<ee ref>-<omnibus ref>
      #   See https://gitlab.com/gitlab-org/release/docs/blob/master/general/deploy/auto-deploy.md#auto-deploy-tagging
      #
      # For nightly builds we fetch all GitLab components from master branch
      # If there was no change inside of the omnibus-gitlab repository, the
      # package version will remain the same but contents of the package will be
      # different.
      # To resolve this, we append a PIPELINE_ID to change the name of the package
      def semver_version
        if Build::Check.on_tag?
          # timestamp is disabled in omnibus configuration
          Omnibus.load_configuration('omnibus.rb')
          Omnibus::BuildVersion.semver
        else
          latest_git_tag = Info::Git.latest_tag.strip
          latest_version = latest_git_tag && !latest_git_tag.empty? ? latest_git_tag[0, latest_git_tag.match("[+]").begin(0)] : '0.0.1'
          commit_sha = Build::Info::Git.commit_sha
          ver_tag = "#{latest_version}+" + (Build::Check.is_nightly? ? "rnightly" : "rfbranch")
          ver_tag += ".fips" if Build::Check.use_system_ssl?
          [ver_tag, Gitlab::Util.get_env('CI_PIPELINE_ID'), commit_sha].compact.join('.')
        end
      end

      def release_version
        semver = Info.semver_version
        "#{semver}-#{Gitlab::BuildIteration.new.build_iteration}"
      end

      def docker_tag
        Gitlab::Util.get_env('IMAGE_TAG') || Info.release_version.tr('+', '-')
      end

      def gitlab_version
        # Get the branch/version/commit of GitLab CE/EE repo against which package
        # is built. If GITLAB_VERSION variable is specified, as in triggered builds,
        # we use that. Else, we use the value in VERSION file.

        if Gitlab::Util.get_env('GITLAB_VERSION').nil? || Gitlab::Util.get_env('GITLAB_VERSION').empty?
          File.read('VERSION').strip
        else
          Gitlab::Util.get_env('GITLAB_VERSION')
        end
      end

      def gitlab_version_slug
        gitlab_version.downcase
          .gsub(/[^a-z0-9]/, '-')[0..62]
          .gsub(/(\A-+|-+\z)/, '')
      end

      def gitlab_rails_ref(prepend_version: true)
        # Returns the immutable git ref of GitLab rails being used.
        #
        # 1. In feature branch pipelines, generate-facts job will create
        #    version fact files which will contain the commit SHA of GitLab
        #    rails. This will be used by `Gitlab::Version` class and will be
        #    presented as version of `gitlab-rails` software component.
        # 2. In stable branch and tag pipelines, these version fact files will
        #    not be created. However, in such cases, VERSION file will be
        #    anyway pointing to immutable references (git tags), and hence we
        #    can directly use it.
        Gitlab::Version.new('gitlab-rails').print(prepend_version)
      end

      def gitlab_rails_project_path
        if Gitlab::Util.get_env('CI_SERVER_HOST') == 'dev.gitlab.org'
          package == "gitlab-ee" ? 'gitlab/gitlab-ee' : 'gitlab/gitlabhq'
        else
          namespace = Gitlab::Version.security_channel? ? "gitlab-org/security" : "gitlab-org"
          project = package == "gitlab-ee" ? 'gitlab' : 'gitlab-foss'

          "#{namespace}/#{project}"
        end
      end

      def gitlab_rails_repo
        gitlab_rails =
          if package == "gitlab-ce"
            "gitlab-rails"
          else
            "gitlab-rails-ee"
          end

        Gitlab::Version.new(gitlab_rails).remote
      end

      def qa_image
        Gitlab::Util.get_env('QA_IMAGE') || "#{Gitlab::Util.get_env('CI_REGISTRY')}/#{gitlab_rails_project_path}/#{Build::Info.package}-qa:#{gitlab_rails_ref(prepend_version: false)}"
      end

      def edition
        Info.package.gsub("gitlab-", "").strip # 'ee' or 'ce'
      end

      def release_bucket
        # Tag builds are releases and they get pushed to a specific S3 bucket
        # whereas regular branch builds use a separate one
        downloads_bucket = Gitlab::Util.get_env('RELEASE_BUCKET') || "downloads-packages"
        builds_bucket = Gitlab::Util.get_env('BUILDS_BUCKET') || "omnibus-builds"
        Check.on_tag? ? downloads_bucket : builds_bucket
      end

      def release_bucket_region
        Gitlab::Util.get_env('RELEASE_BUCKET_REGION') || "eu-west-1"
      end

      def release_bucket_s3_endpoint
        Gitlab::Util.get_env('RELEASE_BUCKET_S3_ENDPOINT') || "s3.amazonaws.com"
      end

      def gcp_release_bucket
        # All tagged builds are pushed to the release bucket
        # whereas regular branch builds use a separate one
        gcp_pkgs_release_bucket = Gitlab::Util.get_env('GITLAB_COM_PKGS_RELEASE_BUCKET') || 'gitlab-com-pkgs-release'
        gcp_pkgs_builds_bucket = Gitlab::Util.get_env('GITLAB_COM_PKGS_BUILDS_BUCKET') || 'gitlab-com-pkgs-builds'
        Check.on_tag? ? gcp_pkgs_release_bucket : gcp_pkgs_builds_bucket
      end

      def gcp_release_bucket_sa_file
        Gitlab::Util.get_env('GITLAB_COM_PKGS_SA_FILE')
      end

      def log_level
        if Gitlab::Util.get_env('BUILD_LOG_LEVEL') && !Gitlab::Util.get_env('BUILD_LOG_LEVEL').empty?
          Gitlab::Util.get_env('BUILD_LOG_LEVEL')
        else
          'info'
        end
      end

      def release_file_contents
        repo = Gitlab::Util.get_env('PACKAGECLOUD_REPO') # Target repository

        download_url = if /dev.gitlab.org/.match?(Build::Info::CI.api_v4_url)
                         Build::Info::CI.package_download_url
                       else
                         Build::Info::CI.triggered_package_download_url
                       end

        raise "Unable to identify package download URL." unless download_url

        contents = []
        contents << "PACKAGECLOUD_REPO=#{repo.chomp}\n" if repo && !repo.empty?
        contents << "RELEASE_PACKAGE=#{Info.package}\n"
        contents << "RELEASE_VERSION=#{Info.release_version}\n"
        contents << "DOWNLOAD_URL=#{download_url}\n"
        contents << "CI_JOB_TOKEN=#{Build::Info::CI.job_token}\n"
        contents.join
      end

      def image_reference
        "#{Build::GitlabImage.gitlab_registry_image_address}:#{Info.docker_tag}"
      end

      def deploy_env_key
        if Build::Check.is_auto_deploy_tag?
          'AUTO_DEPLOY_ENVIRONMENT'
        elsif Build::Check.is_rc_tag?
          'PATCH_DEPLOY_ENVIRONMENT'
        elsif Build::Check.is_latest_stable_tag?
          'RELEASE_DEPLOY_ENVIRONMENT'
        end
      end

      def deploy_env
        key = deploy_env_key

        return nil if key.nil?

        env = Gitlab::Util.get_env(key)

        abort "Unable to determine which environment to deploy too, #{key} is empty" unless env

        puts "Ready to send trigger for environment(s): #{env}"

        env
      end

      def package_list
        Dir.glob(PACKAGE_GLOB)
      end

      def name_version
        Omnibus.load_configuration('omnibus.rb')
        project = Omnibus::Project.load('gitlab')
        packager = project.packagers_for_system[0]

        case packager
        when Omnibus::Packager::DEB
          "#{Build::Info.package}=#{packager.safe_version}-#{packager.safe_build_iteration}"
        when Omnibus::Packager::RPM
          "#{Build::Info.package}-#{packager.safe_version}-#{packager.safe_build_iteration}#{packager.dist_tag}"
        else
          raise "Unable to detect version"
        end
      end
    end
  end
end
