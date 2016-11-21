#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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

# Configure Prometheus Services
[
  "prometheus",
  "node-exporter",
  "redis-exporter"
].each do |service|
  if node["gitlab"][service]["enable"]
    include_recipe "gitlab::#{service}"
  else
    include_recipe "gitlab::#{service}_disable"
  end
end
