#--
# Copyright 2016 Red Hat, Inc.
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
      class InstallDocker
        include CommandHelper
        include InstallHelper

        def initialize(app, env, options)
          @app = app
          @env = env
          @options = options.clone
        end

        def call(env)
          # Migrate our install script to the host machine
          ssh_user = @env[:machine].ssh_info[:username]
          destination="/home/#{ssh_user}/"
          @env[:machine].communicate.upload(File.join(__dir__,"/../resources/configure_docker.sh"), destination)
          home="#{destination}/resources"

          isolated_install(
            @env[:machine],
            'docker',
            @options[:"docker.version"],
            @options[:"docker.repourls"],
            @options[:"docker.reponames"],
            @options[:force]
          )

          # Configure the Docker daemon
          if @options[:skip_volume_group]
            skip_volume_group = "SKIP_VG=true"
          else
            skip_volume_group = ""
          end
          sudo(@env[:machine], "#{skip_volume_group} SSH_USER='#{ssh_user}' #{home}/configure_docker.sh", :timeout=>60*30)

          @app.call(@env)
        end
      end
    end
  end
end