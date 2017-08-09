require_relative 'build.rb'

class PackageRepository
  def target
    # Override
    return ENV['PACKAGECLOUD_REPO'] if ENV['PACKAGECLOUD_REPO'] && !ENV['PACKAGECLOUD_REPO'].empty?
    # Repository for raspberry pi
    return ENV['RASPBERRY_REPO'] if ENV['RASPBERRY_REPO'] && !ENV['RASPBERRY_REPO'].empty?

    rc_repository = repository_for_rc
    if rc_repository
      rc_repository
    else
      Build.package
    end
  end

  def repository_for_rc
    "unstable" if system('git describe | grep -q -e rc')
  end

  def upload(repository = nil, dry_run = false)
    if upload_user.nil?
      puts "User for uploading to package server not specified!"
      return
    end

    # For CentOS 6 and 7 we will upload the same package to Scientific and Oracle Linux
    # For all other OSs, we only upload one package.
    upload_list = package_list(repository)
    if upload_list.empty?
      puts "No packages found for upload. Are artifacts available?"
      return
    end

    upload_list.each do |pkg|
      # bin/package_cloud push gitlab/unstable/ubuntu/xenial gitlab-ce.deb  --url=https://packages.gitlab.com
      cmd = "LC_ALL='en_US.UTF-8' bin/package_cloud push #{upload_user}/#{pkg} --url=https://packages.gitlab.com"
      puts "Uploading...\n"

      if dry_run
        puts cmd
      else
        raise "Upload to package server failed!." unless system(cmd)
      end
    end
  end

  private

  def package_list(repository)
    list = []

    Dir.glob("pkg/**/*.{deb,rpm}").each do |path|
      platform_path = path.split("/") # ['pkg', 'ubuntu-xenial', 'gitlab-ce.deb']

      if platform_path.size != 3
        list_dir_contents = `ls -la pkg/`
        raise "Found unexpected contents in the directory:\n #{list_dir_contents}"
      end

      platform_name = platform_path[1] # "ubuntu-xenial"
      package_name = platform_path[2] # "gitlab-ce.deb"
      package_path = "#{platform_path[0]}/#{platform_name}/#{package_name}"
      platform = platform_name.tr("-", "/") # "ubuntu/xenial"
      target_repository = repository || target # staging override or the rest, eg. "unstable"

      # If we detect Enterprise Linux, upload the same package
      # to Scientific and Oracle Linux repositories
      if platform.start_with?("el/")
        %w(scientific ol).each do |distro|
          platform_path = platform.gsub('el', distro)

          list << "#{target_repository}/#{platform_path} #{package_path}"
        end
      end

      list << "#{target_repository}/#{platform} #{package_path}" # "unstable/ubuntu/xenial gitlab-ce.deb"
    end

    list
  end

  def upload_user
    ENV['PACKAGECLOUD_USER'] if ENV['PACKAGECLOUD_USER'] && !ENV['PACKAGECLOUD_USER'].empty?
  end
end
