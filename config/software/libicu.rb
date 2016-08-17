#
## Copyright:: Copyright (c) 2014 GitLab B.V.
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

name "libicu"
default_version "57.1"

source url: "http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-src.tgz",
       sha256: "ff8c67cb65949b1e7808f2359f2b80f722697048e90e7cfc382ec1fe229e9581"

license "MIT"
license_file "license.html"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  env['LD_RPATH'] = "#{install_dir}/embedded/lib"
  cwd = "#{Omnibus::Config.source_dir}/libicu/icu/source"

  command ["./runConfigureICU",
           "Linux/gcc",
           "--prefix=#{install_dir}/embedded",
           "--with-data-packaging=files",
           "--enable-shared",
           "--without-samples"
     ].join(" "), env: env, cwd: cwd

  make "-j #{workers}", env: env, cwd: cwd
  make "install", env: env, cwd: cwd

  link "#{install_dir}/embedded/share/icu/#{default_version}", "#{install_dir}/embedded/share/icu/current", force: true
end
