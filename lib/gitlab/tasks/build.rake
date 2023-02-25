require 'fileutils'
require_relative "../build.rb"
require_relative "../build/check.rb"
require_relative "../build/info.rb"
require_relative '../build/facts'
require_relative "../ohai_helper.rb"
require_relative '../version.rb'
require_relative "../util.rb"
require_relative "../package_size"
require 'net/http'
require 'json'

namespace :build do
  desc 'Start project build'
  task project: ["cache:purge", "check:no_changes"] do
    Gitlab::Util.section('build:project') do
      Build.exec('gitlab') || raise('Build failed')
    end

    Rake::Task["license:check"].invoke
    Rake::Task["build:package:move_to_platform_dir"].invoke
    Rake::Task["build:package:generate_checksums"].invoke
    Rake::Task["build:package:generate_sizefile"].invoke
  end

  namespace :docker do
    desc 'Show latest available tag. Includes unstable releases.'
    task :latest_tag do
      puts Build::Info.latest_tag
    end

    desc 'Show latest stable tag.'
    task :latest_stable_tag do
      puts Build::Info.latest_stable_tag
    end
  end

  namespace :package do
    desc "Move packages to OS specific directory"
    task :move_to_platform_dir do
      FileUtils.mv("pkg/version-manifest.json", "pkg/#{Build::Info.package}_#{Build::Info.release_version}.version-manifest.json")
      platform_dir = OhaiHelper.platform_dir
      FileUtils.mv("pkg", platform_dir)
      FileUtils.mkdir("pkg")
      FileUtils.mv(platform_dir, "pkg")
    end

    desc "Generate checksums for each file"
    task :generate_checksums do
      Gitlab::Util.section('build:package:generate_checksums') do
        files = Dir.glob('pkg/**/*.{deb,rpm}').select { |f| File.file? f }
        files.each do |file|
          system('sha256sum', file, out: "#{file}.sha256")
        end
      end
    end

    desc "Generate sizefile for each file"
    task :generate_sizefile do
      Gitlab::Util.section('build:package:generate_sizefile') do
        files = Dir.glob('pkg/**/*.{deb,rpm}').select { |f| File.file? f }
        if files.empty?
          # We are probably inside Trigger:package_size_check job.
          PackageSizeCheck.fetch_sizefile
        else
          PackageSizeCheck.generate_sizefiles(files)
        end
      end
    end

    desc "Sync packages to aws and gcp"
    task :sync do
      Gitlab::Util.section('build:package:sync', collapsed: Build::Check.on_tag?) do
        pkgs_sa_file = Build::Info.gcp_release_bucket_sa_file
        if pkgs_sa_file && Build::Check.is_auto_deploy_tag?
          pkgs_bucket = Build::Info.gcp_release_bucket
          puts 'GCS Sync: Activating service account'
          activate_ret = system(*%W[/usr/local/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file #{pkgs_sa_file}])
          if activate_ret
            puts "GCS Sync: Copying pkg/ contents to #{pkgs_bucket}"
            gsutil_ret = system(*%W[/usr/local/google-cloud-sdk/bin/gsutil -m rsync -r pkg/ gs://#{pkgs_bucket}])
            puts "GCS Sync: Rsync success: #{gsutil_ret}"
          end
        end
        release_bucket = Build::Info.release_bucket
        release_bucket_region = Build::Info.release_bucket_region
        release_bucket_s3_endpoint = Build::Info.release_bucket_s3_endpoint
        puts "AWS S3 Sync: Copying pkg/ contents to #{release_bucket_s3_endpoint}"
        system(*%W[aws s3 --endpoint-url https://#{release_bucket_s3_endpoint} sync pkg/ s3://#{release_bucket} --no-progress --acl public-read --region #{release_bucket_region}])
        files = Dir.glob('pkg/**/*').select { |f| File.file? f }
        files.each do |file|
          puts file.gsub('pkg', "https://#{release_bucket}.#{release_bucket_s3_endpoint}").gsub('+', '%2B')
        end
      end
    end

    desc "Package name"
    task :name do
      puts Build::Info.package
    end

    desc 'Print the package name-version string to install the specific version of package'
    task :name_version do
      puts Build::Info.name_version
    end
  end

  desc 'Print the current version'
  task :version do
    # We don't differentiate between CE and EE here since they use the same version file
    puts Gitlab::Version.new('gitlab-rails').print
  end

  desc 'Print SHAs of GitLab components'
  task :component_shas do
    version_manifest_file = Dir.glob('pkg/**/*version-manifest.json').first
    return unless version_manifest_file

    Gitlab::Util.section('build:component_shas') do
      puts "#### SHAs of GitLab Components"
      Build::Facts.get_component_shas(version_manifest_file).each do |component, sha|
        puts "#{component} : #{sha}"
      end
    end
  end

  desc 'Write build related facts to file'
  task :generate_facts do
    FileUtils.mkdir_p('build_facts')

    Build::Facts.generate
  end
end
