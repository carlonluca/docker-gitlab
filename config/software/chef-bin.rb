#
# Copyright 2020-2022 GitLab Inc.
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

name 'chef-bin'
# The version here should be in agreement with /Gemfile.lock so that our rspec
# testing stays consistent with the package contents.
default_version '17.10.0'

license 'Apache-2.0'
license_file 'LICENSE'

skip_transitive_dependency_licensing true

dependency 'ruby'
dependency 'rubygems'

build do
  env = with_standard_compiler_flags(with_embedded_path)
  patch source: 'add-license-file.patch'

  gem 'install chef-bin' \
      " --clear-sources" \
      " -s https://packagecloud.io/cinc-project/stable" \
      " -s https://rubygems.org" \
      " --version '#{version}'" \
      " --bindir '#{install_dir}/embedded/bin'" \
      ' --no-document', env: env
end
