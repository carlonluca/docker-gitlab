#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
<<<<<<< HEAD:files/gitlab-cookbooks/monitoring/recipes/gitlab-exporter_disable.rb
# Copyright:: Copyright (c) 2016 GitLab Inc.
=======
# Copyright:: Copyright (c) 2017 GitLab Inc.
>>>>>>> 13.12.3+ce.0:files/gitlab-cookbooks/gitlab-ee/recipes/geo-postgresql_disable.rb
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

<<<<<<< HEAD:files/gitlab-cookbooks/monitoring/recipes/gitlab-exporter_disable.rb
runit_service "gitlab-exporter" do
=======
runit_service 'geo-postgresql' do
>>>>>>> 13.12.3+ce.0:files/gitlab-cookbooks/gitlab-ee/recipes/geo-postgresql_disable.rb
  action :disable
end
>>>>>>> /tmp/meld-tmp-Remotetzm9ug_r
