#
# Copyright 2012-2014 Chef Software, Inc.
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

name 'redis'

license 'BSD-3-Clause'
license_file 'COPYING'

skip_transitive_dependency_licensing true

dependency 'config_guess'
default_version '3.2.12'

source url: "http://download.redis.io/releases/redis-#{version}.tar.gz",
       md5: 'b005ef8161ee1e9f67d10af5bab28093'

relative_path "redis-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path).merge(
    'PREFIX' => "#{install_dir}/embedded"
  )

  update_config_guess

  make "-j #{workers}", env: env
  make 'install', env: env
end
