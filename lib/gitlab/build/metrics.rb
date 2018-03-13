require_relative "info.rb"
require "google_drive"

module Build
  class Metrics
    class << self
      def configure_gitlab_repo
        # Install recommended softwares for installing GitLab EE
        system("apt-get update && apt-get install -y curl openssh-server ca-certificates")
        system("curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash")
      end

      def install_package(version, upgrade: false)
        # Deleting RUBY and BUNDLE related env variables so rake tasks ran
        # during reconfigure won't use gems from builder image.
        ENV.delete_if { |name, _v| name =~ /^(RUBY|BUNDLE)/ }
        system("EXTERNAL_URL='http://gitlab.example.com' apt-get -y install gitlab-ee=#{version}")
        return if upgrade # If upgrade, the following will be handled automatically

        system("/opt/gitlab/embedded/bin/runsvdir-start &")
        system("gitlab-ctl reconfigure")
      end

      def should_upgrade?
        # We need not update if the tag is either from an older version series or a
        # patch release or a CE version.
        status = true
        if !Build::Check.is_ee?
          puts "Not an EE package. Not upgrading."
          status = false
        elsif Build::Check.is_patch_release?
          puts "Not a major/minor release. Not upgrading."
          status = false
        elsif !Build::Check.add_latest_tag?
          # Checking if latest stable release.
          # TODO: Refactor the method name to be more explanatory
          # https://gitlab.com/gitlab-org/omnibus-gitlab/issues/3274
          puts "Not a latest stable release. Not upgrading."
          status = false
        end
        status
      end

      def get_latest_log(final_location)
        # Getting last block from log to a separate file.
        log_location = "/var/log/apt/term.log"

        # 1. tac will reverse the log and give it to sed
        # 2. sed will get the string till the first "Log started" string
        #    (which corresponds to the last log block).
        # 3. Next tac will again reverse it, hence producing log in proper order
        system("tac #{log_location} | sed '/^Log started/q' | tac > #{final_location}")
      end

      def calculate_duration
        latest_log_location = "/tmp/upgrade.log"
        get_latest_log(latest_log_location)

        # Logs from apt follow the format `Log (started|ended): <date>  <time>`
        start_string = File.open(latest_log_location).grep(/Log started/)[0].strip.gsub("Log started: ", "")
        end_string = File.open(latest_log_location).grep(/Log ended/)[0].strip.gsub("Log ended: ", "")
        start_time = DateTime.strptime(start_string, "%Y-%m-%d  %H:%M:%S")
        end_time = DateTime.strptime(end_string, "%Y-%m-%d  %H:%M:%S")

        # Duration in seconds
        ((end_time - start_time) * 24 * 60 * 60).to_i
      end

      def append_to_sheet(version, duration)
        # Append duration to Google Sheets where a chart will be generated
        service_account_file = File.expand_path("../../../../service_account.json", __FILE__)
        session = GoogleDrive::Session.from_service_account_key(service_account_file)
        spreadsheet = session.spreadsheet_by_title("GitLab EE Upgrade Metrics")
        worksheet = spreadsheet.worksheets.first
        worksheet.insert_rows(worksheet.num_rows + 1, [[version, duration]])
        worksheet.save
      end
    end
  end
end
