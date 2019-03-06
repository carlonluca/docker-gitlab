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

version = Gitlab::Version.new('gitlab-monitor', '3.2.0')

default_version version.print

name 'gitlab-monitor'
license 'MIT'
license_file 'LICENSE'

skip_transitive_dependency_licensing true

dependency 'ruby'
dependency 'rubygems'
dependency 'postgresql'

source git: version.remote

build do
  env = with_standard_compiler_flags(with_embedded_path)

  gem 'build gitlab-monitor.gemspec', env: env
  gem 'install gitlab-monitor' \
      " --bindir '#{install_dir}/embedded/bin'" \
      ' --no-document', env: env
end
