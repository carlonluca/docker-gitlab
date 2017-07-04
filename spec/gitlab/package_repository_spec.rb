require_relative '../../lib/gitlab/package_repository.rb'
require 'chef_helper'

describe PackageRepository do
  let(:repo) { PackageRepository.new }

  describe :repository_for_rc do
    context 'on master' do
      # Example:
      # on non stable branch: 8.1.0+rc1.ce.0-1685-gd2a2c51
      # on tag: 8.12.0+rc1.ee.0
      before do
        allow(repo).to receive(:system).with('git describe | grep -q -e rc').and_return(true)
      end

      it { expect(repo.repository_for_rc).to eq 'unstable' }
    end

    context 'on stable branch' do
      # Example:
      # on non stable branch: 8.12.8+ce.0-1-gdac92d4
      # on tag: 8.12.8+ce.0
      before do
        allow(repo).to receive(:system).with('git describe | grep -q -e rc').and_return(false)
      end

      it { expect(repo.repository_for_rc).to eq nil }
    end
  end

  describe :target do
    shared_examples 'with an override repository' do
      context 'with repository override' do
        before do
          set_all_env_variables
        end

        it 'uses the override repository' do
          expect(repo.target).to eq('super-stable-1234')
        end
      end
    end

    shared_examples 'with a nightly repository' do
      context 'with nightly repo' do
        before do
          set_nightly_env_variable
        end

        it 'uses the nightly repository' do
          expect(repo.target).to eq('nightly-builds')
        end
      end
    end

    shared_examples 'with raspberry pi repo' do
      context 'with raspberry pi repo' do
        before do
          set_raspi_env_variable
        end

        it 'uses the raspberry pi repository' do
          expect(repo.target).to eq('raspi')
        end
      end
    end

    context 'on non-stable branch' do
      before do
        allow(repo).to receive(:system).with('git describe | grep -q -e rc').and_return(true)
      end

      it 'prints unstable' do
        expect(repo.target).to eq('unstable')
      end

      it_behaves_like 'with an override repository'
      it_behaves_like 'with a nightly repository'
      it_behaves_like 'with raspberry pi repo'
    end

    context 'on a stable branch' do
      before do
        allow(repo).to receive(:system).with('git describe | grep -q -e rc').and_return(false)
      end

      context 'when EE' do
        before do
          allow(Build).to receive(:system).with('grep -q -E "\-ee" VERSION').and_return(true)
        end

        it 'prints gitlab-ee' do
          expect(repo.target).to eq('gitlab-ee')
        end

        it_behaves_like 'with an override repository'
        it_behaves_like 'with a nightly repository'
        it_behaves_like 'with raspberry pi repo'
      end

      context 'when CE' do
        before do
          allow(Build).to receive(:system).with('grep -q -E "\-ee" VERSION').and_return(false)
        end

        it 'prints gitlab-ce' do
          expect(repo.target).to eq('gitlab-ce')
        end

        it_behaves_like 'with an override repository'
        it_behaves_like 'with a nightly repository'
        it_behaves_like 'with raspberry pi repo'
      end
    end
  end

  describe :upload do
    describe 'with staging repository' do
      context 'when upload user is not specified' do
        it 'prints a message and aborts' do
          expect(repo.upload('my-staging-repository', true)).to eq('User for uploading to package server not specified!')
        end
      end

      context 'with specified upload user' do
        before do
          stub_env_var('PACKAGECLOUD_USER', "gitlab")
        end

        context 'with artifacts available' do
          before do
            allow(Dir).to receive(:glob).with("pkg/**/*.{deb,rpm}").and_return(['pkg/el-6/gitlab-ce.rpm'])
          end

          it 'in dry run mode prints the upload commands' do
            expect { repo.upload('my-staging-repository', true) }.to output(%r{Uploading...\n}).to_stdout
            expect { repo.upload('my-staging-repository', true) }.to output(%r{bin/package_cloud push gitlab/my-staging-repository/sc/6 gitlab-ce.rpm --url=https://packages.gitlab.com\n}).to_stdout
            expect { repo.upload('my-staging-repository', true) }.to output(%r{bin/package_cloud push gitlab/my-staging-repository/ol/6 gitlab-ce.rpm --url=https://packages.gitlab.com\n}).to_stdout
            expect { repo.upload('my-staging-repository', true) }.to output(%r{bin/package_cloud push gitlab/my-staging-repository/el/6 gitlab-ce.rpm --url=https://packages.gitlab.com\n}).to_stdout
          end
        end

        context 'with artifacts unavailable' do
          before do
            allow(Dir).to receive(:glob).with("pkg/**/*.{deb,rpm}").and_return([])
          end

          it 'prints a message and aborts' do
            expect(repo.upload('my-staging-repository', true)).to eq('No packages found for upload. Are artifacts available?')
          end
        end
      end
    end

    describe "with production repository" do
      context 'with artifacts available' do
        before do
          stub_env_var('PACKAGECLOUD_USER', "gitlab")
          allow(Dir).to receive(:glob).with("pkg/**/*.{deb,rpm}").and_return(['pkg/ubuntu-xenial/gitlab.deb'])
        end

        context 'for stable release' do
          before do
            stub_env_var('PACKAGECLOUD_REPO', nil)
            stub_env_var('RASPBERRY_REPO', nil)
            stub_env_var('NIGHTLY_REPO', nil)
            allow_any_instance_of(PackageRepository).to receive(:repository_for_rc).and_return(nil)
          end

          context 'of EE' do
            before do
              stub_env_var('ee', 'true')
            end

            it 'in dry run mode prints the upload commands' do
              expect { repo.upload(nil, true) }.to output(%r{Uploading...\n}).to_stdout
              expect { repo.upload(nil, true) }.to output(%r{bin/package_cloud push gitlab/gitlab-ee/ubuntu/xenial gitlab.deb --url=https://packages.gitlab.com\n}).to_stdout
            end
          end

          context 'of CE' do
            before do
              stub_env_var('ee', nil)
            end

            it 'in dry run mode prints the upload commands' do
              expect { repo.upload(nil, true) }.to output(%r{Uploading...\n}).to_stdout
              expect { repo.upload(nil, true) }.to output(%r{bin/package_cloud push gitlab/gitlab-ce/ubuntu/xenial gitlab.deb --url=https://packages.gitlab.com\n}).to_stdout
            end
          end
        end

        context 'for nightly release' do
          before do
            set_nightly_env_variable
            allow_any_instance_of(PackageRepository).to receive(:repository_for_rc).and_return(nil)
          end

          it 'in dry run mode prints the upload commands' do
            expect { repo.upload(nil, true) }.to output(%r{Uploading...\n}).to_stdout
            expect { repo.upload(nil, true) }.to output(%r{bin/package_cloud push gitlab/nightly-builds/ubuntu/xenial gitlab.deb --url=https://packages.gitlab.com\n}).to_stdout
          end
        end

        context 'for raspbian release' do
          before do
            set_raspi_env_variable
            allow_any_instance_of(PackageRepository).to receive(:repository_for_rc).and_return(nil)
          end

          it 'in dry run mode prints the upload commands' do
            expect { repo.upload(nil, true) }.to output(%r{Uploading...\n}).to_stdout
            expect { repo.upload(nil, true) }.to output(%r{bin/package_cloud push gitlab/raspi/ubuntu/xenial gitlab.deb --url=https://packages.gitlab.com\n}).to_stdout
          end
        end
      end
    end

    describe 'when artifacts contain unexpected files' do
      before do
        stub_env_var('PACKAGECLOUD_USER', "gitlab")
        set_all_env_variables
        allow(Dir).to receive(:glob).with("pkg/**/*.{deb,rpm}").and_return(['pkg/ubuntu-xenial/gitlab.deb', 'pkg/ubuntu-xenial/testing/gitlab.deb'])
      end

      it 'raises an exception' do
        expect { repo.upload(nil, true) }.to raise_exception(%r{Found unexpected contents in the directory:})
      end
    end
  end

  def set_all_env_variables
    stub_env_var("PACKAGECLOUD_REPO", "super-stable-1234")
    stub_env_var("NIGHTLY_REPO", "nightly-builds")
    stub_env_var("RASPBERRY_REPO", "raspi")
  end

  def set_nightly_env_variable
    stub_env_var("PACKAGECLOUD_REPO", "")
    stub_env_var("NIGHTLY_REPO", "nightly-builds")
    stub_env_var("RASPBERRY_REPO", "")
  end

  def set_raspi_env_variable
    stub_env_var("PACKAGECLOUD_REPO", "")
    stub_env_var("NIGHTLY_REPO", "nightly-builds")
    stub_env_var("RASPBERRY_REPO", "raspi")
  end
end
