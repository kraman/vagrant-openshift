#--
# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

module Vagrant
  module Openshift
    module Action
      class CheckoutRepositories
        include CommandHelper

        def initialize(app, env, options={})
          @app = app
          @env = env
          @options = options
        end

        def call(env)
          git_clone_commands = ""
          Constants.repos.each do |repo_name, url|
            bare_repo_name = repo_name + "-bare"
            bare_repo_path = Constants.build_dir + bare_repo_name
            repo_path = Constants.build_dir + repo_name

            git_clone_commands += "rm -rf #{repo_path}; git clone #{bare_repo_path} #{repo_path}; "
            if @options[:branch] && @options[:branch][repo_name]
              git_clone_commands += "cd #{repo_path}; git checkout #{@options[:branch][repo_name]}; cd #{Constants.build_dir}; "
            end
          end
          do_execute env[:machine], git_clone_commands

          @app.call(env)
        end
      end
    end
  end
end