source 'https://rubygems.org'

require_relative "lib/gitlab/version"

omnibus_gem_version = Gitlab::Version.new('omnibus', "gitlab-omnibus-v5.6.12")

# Note that omnibus is from a fork with additional gitlab changes.  You can
# check what they are with the following comparison link:

# https://gitlab.com/gitlab-org/omnibus/compare/v5.6.10...gitlab-omnibus-v5.6.10
#
# * Adds code to generate dependency_licenses.json
# * Modifies generation of #{install_dir}/LICENSE to be a combination of all
#   component licenses.

# When updating gem versions:
# 1. Edit this file to specify pinning if needed
# 2. `bundle upgrade GEM`
# 3. Inspect and check-in Gemfile.lock
# 4. Check that the changes to Gemfile.lock are propogated to the software
#    definitions in `config/software`.  You can find them quickly with:
#      grep "gem 'install " config/software/*

gem 'omnibus', git: omnibus_gem_version.remote, branch: omnibus_gem_version.print(false)
gem 'chef', '13.6.4'
gem 'ohai'
gem 'package_cloud'
gem 'rainbow', '~> 2.2' # This is used by gitlab-ctl and the chef formatter
gem 'thor', '0.18.1' # This specific version is required by package_cloud
gem 'json'
gem 'rspec'
gem 'rake'
gem 'knapsack'
gem 'docker-api'
gem 'aws-sdk'
gem 'google_drive'
gem 'http'

group :rubocop do
  gem 'rubocop'
  gem 'rubocop-rspec'
end

group :test do
  gem 'byebug'
  gem 'chefspec'
  gem 'omnibus-ctl', '0.3.6'
  gem 'fantaskspec'
  gem 'rspec_junit_formatter'
  gem 'pry'
end
