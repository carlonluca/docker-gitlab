#
# Copyright:: Copyright (c) 2020 GitLab Inc
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

# Creates version file.

resource_name :version_file
provides :version_file

actions :create
default_action :create

property :version_file_path, [String, nil], default: nil
property :version_check_cmd, [String, nil], default: nil

action :create do
  file new_resource.version_file_path do
    content VersionHelper.version(new_resource.version_check_cmd)
  end
end
