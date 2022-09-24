#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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

name 'gpgme'

default_version '1.17.0'

dependency 'libassuan'
dependency 'gnupg'
dependency 'zlib'

license 'LGPL-2.1'
license_file 'COPYING.LESSER'

skip_transitive_dependency_licensing true

source url: "https://www.gnupg.org/ftp/gcrypt/gpgme/gpgme-#{version}.tar.bz2",
       sha256: '4ed3f50ceb7be2fce2c291414256b20c9ebf4c03fddb922c88cda99c119a69f5'

relative_path "gpgme-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  env['CFLAGS'] << ' -std=c99'
  command './configure ' \
    "--prefix=#{install_dir}/embedded --disable-doc --disable-languages", env: env

  make "-j #{workers}", env: env
  make 'install', env: env
end

project.exclude 'embedded/bin/gpgme-config'
