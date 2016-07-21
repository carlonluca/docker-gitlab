#
# Copyright 2016 GitLab Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# We are pinning chef-zero because version 4.6.0 intorduced very verbose
# output in info log level.
# Introduced by https://github.com/chef/chef-zero/pull/199
# When changing this version, make sure that the verbosity went down.

name "chef-zero"
default_version "4.7.1"

dependency "ruby"
dependency "rubygems"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  gem "install chef-zero" \
      " --version '#{version}'" \
      " --bindir '#{install_dir}/embedded/bin'" \
      " --no-ri --no-rdoc", env: env
  # This patch can be removed on the next chef-zero upgrade
  # because https://github.com/chef/chef-zero/pull/222 was merged.
  patch source: 'chef-zero-2.7.1-log-level-rest-base.patch', target: '/opt/gitlab/embedded/lib/ruby/gems/2.1.0/gems/chef-zero-4.7.1/lib/chef_zero/rest_base.rb'
end
