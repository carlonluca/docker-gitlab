#
# Copyright:: Copyright (c) 2016 GitLab Inc.
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
pg_helper = PgHelper.new(node)
omnibus_helper = OmnibusHelper.new(node)
postgresql_install_dir = File.join(node['package']['install-dir'], 'embedded/postgresql')
postgresql_data_dir = node['gitlab']['postgresql']['data_dir']

# This recipe will also be called standalone so the resource
# won't exist for resource collection.
# We only have ourselves to blame here, we want DRY code this is what we get.
# The block below is cleanest solution and
# was found at https://gist.github.com/scalp42/7606857#gistcomment-1618630
resource_exists = proc do |name|
  begin
    resources name
    true
  rescue Chef::Exceptions::ResourceNotFound
    false
  end
end

ruby_block "Link postgresql bin files to the correct version" do
  block do
    pg_version = pg_helper.database_version || pg_helper.version
    pg_path = Dir.glob("#{postgresql_install_dir}/#{pg_version}*").first
    Dir.glob("#{pg_path}/bin/*").each do |pg_bin|
      FileUtils.ln_sf(pg_bin, "#{node['package']['install-dir']}/embedded/bin/#{File.basename(pg_bin)}")
    end
  end
  only_if do
    !File.exists?(File.join(postgresql_data_dir, "PG_VERSION")) || pg_helper.version !~ /^#{pg_helper.database_version}/
  end
  notifies :restart, 'service[postgresql]', :immediately if omnibus_helper.should_notify?("postgresql") && resource_exists['service[postgresql]']
end
