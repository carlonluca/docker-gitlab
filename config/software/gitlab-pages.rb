#
# Copyright:: Copyright (c) 2016 GitLab B.V.
# License:: Apache License, Version 2.0
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
require "#{Omnibus::Config.project_root}/lib/gitlab/version"
version = Gitlab::Version.new("GITLAB_PAGES_VERSION")

name "gitlab-pages"
default_version version.print

source :git => version.remote

build do
  # We use the `base_dir`, because the sources are put in `src/gitlab-pages`
  # This is required for GO15VENDOREXPERIMENT=1 to work properly,
  # since it requires the package to be in $GOPATH/src/package
  env = { 'GOPATH' => "#{Omnibus::Config.base_dir}"}
  make "gitlab-pages", env: env
  move "gitlab-pages", "#{install_dir}/embedded/bin/gitlab-pages"
end
