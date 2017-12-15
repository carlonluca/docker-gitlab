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

name 'libgcrypt'
default_version '1.8.1'

dependency 'libgpg-error'

license 'LGPL-2.1'
license_file 'COPYING.LIB'

source url: "https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-#{version}.tar.bz2",
       sha256: '7a2875f8b1ae0301732e878c0cca2c9664ff09ef71408f085c50e332656a78b3'

relative_path "libgcrypt-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  command './configure ' \
    "--prefix=#{install_dir}/embedded --disable-doc", env: env

  make "-j #{workers}", env: env
  make 'install', env: env
end
