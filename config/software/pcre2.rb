#
# Copyright 2018 GitLab Inc.
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

name 'pcre2'

version = Gitlab::Version.new('pcre2', 'pcre2-10.40')
default_version version.print(false)
display_version version.print(false).delete_prefix('pcre2-')

license 'BSD-2-Clause'
license_file 'LICENCE'

skip_transitive_dependency_licensing true

dependency 'libedit'
dependency 'ncurses'
dependency 'config_guess'
dependency 'libtool'

source git: version.remote

build do
  env = with_standard_compiler_flags(with_embedded_path)
  env['CFLAGS'] << ' -std=c99'

  update_config_guess

  command "./autogen.sh", env: env

  command './configure' \
          " --prefix=#{install_dir}/embedded" \
          ' --disable-cpp' \
          ' --enable-jit' \
          ' --enable-pcre2test-libedit', env: env

  make "-j #{workers}", env: env
  make 'install', env: env
end

project.exclude "embedded/bin/pcre2-config"
