#
## Copyright:: Copyright (c) 2016 GitLab Inc
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

name "unzip"
default_version "6.0"

license "Info-ZIP"
license_file "LICENSE"

source url: "http://vorboss.dl.sourceforge.net/project/infozip/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz",
       sha256: "036d96991646d0449ed0aa952e4fbe21b476ce994abc276e49d30e686708bd37"

relative_path "unzip60"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  make "-f unix/Makefile clean", env: env
  make "-j #{workers} -f unix/Makefile generic", env: env
  make "-f unix/Makefile prefix=#{install_dir}/embedded install", env: env
end
