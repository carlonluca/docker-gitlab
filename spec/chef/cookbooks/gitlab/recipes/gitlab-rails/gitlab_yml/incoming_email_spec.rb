require 'chef_helper'

RSpec.describe 'gitlab::gitlab-rails' do
  include_context 'gitlab-rails'

  describe 'incoming email settings' do
    describe 'delete_after_delivery values' do
      context 'with default values' do
        it 'renders gitlab.yml with delete_after_delivery set to true' do
          expect(gitlab_yml[:production][:incoming_email][:delete_after_delivery]).to be true
        end
      end

      context 'with incoming_email_delete_after_delivery set to false' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              incoming_email_delete_after_delivery: false
            }
          )
        end

        it 'renders gitlab.yml with delete_after_delivery set to false' do
          expect(gitlab_yml[:production][:incoming_email][:delete_after_delivery]).to be false
        end
      end
    end

    describe 'log file location' do
      context 'with default values' do
        it 'renders gitlab.yml with default value for mailroom log file path' do
          expect(gitlab_yml[:production][:incoming_email][:log_path]).to eq '/var/log/gitlab/mailroom/mail_room_json.log'
        end
      end

      context 'with custom log file path specified' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              incoming_email_log_file: '/my/custom/log/file'
            }
          )
        end

        it 'renders gitlab.yml with specified value for mailroom log file path' do
          expect(gitlab_yml[:production][:incoming_email][:log_path]).to eq '/my/custom/log/file'
        end
      end

      context 'with custom log directory specified' do
        before do
          stub_gitlab_rb(
            mailroom: {
              log_directory: '/my/custom/directory'
            }
          )
        end

        it 'renders gitlab.yml with default log file name inside specified directory' do
          expect(gitlab_yml[:production][:incoming_email][:log_path]).to eq '/my/custom/directory/mail_room_json.log'
        end
      end

      context 'with custom log file and directory specified' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              incoming_email_log_file: '/foobar.log'
            },
            mailroom: {
              log_directory: '/my/custom/directory'
            }
          )
        end

        it 'renders gitlab.yml with specified log file path irrespective of specified directory' do
          expect(gitlab_yml[:production][:incoming_email][:log_path]).to eq '/foobar.log'
        end
      end
    end
  end
end
