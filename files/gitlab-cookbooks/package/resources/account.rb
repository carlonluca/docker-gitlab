#
# Copyright:: Copyright (c) 2016 GitLab Inc
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

resource_name :account
provides :account

actions :create, :remove
default_action :create

property :username, [String, nil], default: nil
property :uid, [String, Integer, nil], default: nil
property :ugid, [String, Integer, nil], default: nil
property :groupname, [String, nil], default: nil
property :gid, [String, Integer, nil], default: nil
property :shell, [String, nil], default: nil
property :home, [String, nil], default: nil
property :system, [true, false], default: true
property :append_to_group, [true, false], default: false
property :group_members, Array, default: []
property :user_supports, Hash, default: {}
property :manage, [true, false, nil], default: nil

action :create do
  if manage && groupname
    group new_resource.name do
      group_name groupname
      gid new_resource.gid
      system new_resource.system
      if append_to_group
        append true
        members group_members
      end
      action :create
    end
  end

  if manage && new_resource.username
    user new_resource.name do
      username new_resource.username
      shell new_resource.shell
      home new_resource.home
      uid new_resource.uid
      gid new_resource.ugid
      system new_resource.system
      supports user_supports
      action :create
    end
  end
end

action :remove do
  if manage && groupname
    group groupname do
      group_name groupname
      action :remove
    end
  end

  if manage && username
    user new_resource.username do
      username new_resource.username
      action :remove
    end
  end
end
