#
# Copyright:: Copyright (c) 2019 GitLab Inc.
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

require 'chef/mixin/deprecation'

module Gitlab
  # Inspired by DeprecatedInstanceVariable in https://github.com/chef/chef/blob/master/lib/chef/mixin/deprecation.rb
  class ObjectProxy < ::Chef::Mixin::Deprecation::DeprecatedObjectProxyBase
    def initialize(target)
      @target = target
    end

    def method_missing(method_name, *args, &block)
      current_target = target
      (current_target.respond_to?(method_name, true) && current_target.send(method_name, *args, &block)) || super
    end

    def respond_to_missing?(method_name, include_private = false)
      target.send(:respond_to_missing?, method_name, include_private) || super
    end

    [:nil?, :inspect].each do |method_name|
      define_method(method_name) do |*args, &block|
        target.send(method_name, *args, &block)
      end
    end

    def target
      # Support for defered procs/lambdas
      return @target.call if @target.respond_to?(:call)

      @target
    end
  end
end
