#
## Copyright:: Copyright (c) 2014 GitLab.com
## License:: Apache License, Version 2.0
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
#

require "#{Omnibus::Config.project_root}/lib/gitlab/version"
require 'time'

name 'prometheus'
version = Gitlab::Version.new('prometheus', '1.8.2')
default_version version.print

license 'APACHE-2.0'
license_file 'LICENSE'

source git: version.remote

relative_path 'src/github.com/prometheus/prometheus'

build do
  env = {
    'GOPATH' => "#{Omnibus::Config.source_dir}/prometheus",
  }
  exporter_source_dir = "#{Omnibus::Config.source_dir}/prometheus"
  cwd = "#{exporter_source_dir}/src/github.com/prometheus/prometheus"

  common_version = "github.com/prometheus/prometheus/vendor/github.com/prometheus/common/version"
  revision = `git rev-parse HEAD`.strip
  build_time = Time.now.iso8601
  ldflags = [
    "-X #{common_version}.Version=#{version.print(false)}",
    "-X #{common_version}.Revision=#{revision}",
    "-X #{common_version}.Branch=master",
    "-X #{common_version}.BuildUser=GitLab-Omnibus",
    "-X #{common_version}.BuildDate=#{build_time}",
  ].join(' ')

  command "go build -ldflags '#{ldflags}' ./cmd/prometheus", env: env, cwd: cwd
  copy 'prometheus', "#{install_dir}/embedded/bin/"
end
