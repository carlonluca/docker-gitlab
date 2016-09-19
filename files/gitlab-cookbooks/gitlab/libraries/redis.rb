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
require_relative 'redis_uri.rb'

module Redis
  class << self
    def parse_variables
      parse_redis_settings
    end

    def parse_redis_settings
      if is_redis_tcp?
        # The user wants Redis to listen via TCP instead of unix socket.
        Gitlab['redis']['unixsocket'] = false

        # Try to discover gitlab_rails redis connection params
        # based on redis daemon definition if not defined
        Gitlab['gitlab_rails']['redis_host'] ||= Gitlab['redis']['bind']
        Gitlab['gitlab_rails']['redis_port'] ||= Gitlab['redis']['port']

        if Gitlab['gitlab_rails']['redis_host'] != Gitlab['redis']['bind']
          Chef::Log.warn "gitlab-rails 'redis_host' is different than 'bind' value defined for managed redis instance."
        end

        if Gitlab['gitlab_rails']['redis_port'] != Gitlab['redis']['port']
          Chef::Log.warn "gitlab-rails 'redis_port' is different than 'port' value defined for managed redis instance."
        end
      end

      if is_gitlab_rails_redis_tcp?
        # The user wants to connect to a Redis instance via TCP.
        # It can be either a non-bundled instance or a Sentinel based one.
        # Overriding redis_socket to false signals that gitlab-rails
        # should connect to Redis via TCP instead of a Unix domain socket.
        Gitlab['gitlab_rails']['redis_port'] ||= 6379
        Gitlab['gitlab_rails']['redis_socket'] = false
      end
    end

    private

    def is_redis_tcp?
      Gitlab['redis']['bind'] && Gitlab['redis']['port'] != 0
    end

    def is_gitlab_rails_redis_tcp?
      Gitlab['gitlab_rails']['redis_host']
    end
  end
end
