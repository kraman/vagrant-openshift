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
require 'pathname'

module Vagrant
  module Openshift
    class Constants

      def self.repos(env)
        openshift_repos
      end

      def self.logging_repos(env)
        aggregated_logging_repos
      end

      def self.openshift_repos
        {
          'origin' => 'https://github.com/openshift/origin.git',
          'source-to-image' => 'https://github.com/openshift/source-to-image.git',
          'origin-web-console' => 'https://github.com/openshift/origin-web-console.git'
        }
      end

      def self.jenkins_repos
        {
          'jenkins' => 'https://github.com/openshift/jenkins.git',
          'jenkins-plugin' => 'https://github.com/openshift/jenkins-plugin.git',
          'jenkins-client-plugin' => 'https://github.com/openshift/jenkins-client-plugin.git',
          'jenkins-openshift-login-plugin' => 'https://github.com/openshift/jenkins-openshift-login-plugin.git',
          'jenkins-sync-plugin' => 'https://github.com/openshift/jenkins-sync-plugin.git'
        }
      end

      def self.console_repos
        {
          'origin-web-console' => 'https://github.com/openshift/origin-web-console.git'
        }
      end

       def self.aggregated_logging_repos
        {
          'origin-aggregated-logging' => 'https://github.com/openshift/origin-aggregated-logging.git'
        }
      end

      def self.repos_for_name(reponame)
        {
          'origin' => openshift_repos,
          nil => openshift_repos,
          'jenkins' => jenkins_repos,
          'origin-console' => console_repos,
          'origin-aggregated-logging' => aggregated_logging_repos,
          'origin-metrics' => {
            'origin-metrics' => 'https://github.com/openshift/origin-metrics.git'
          },
          'openshift-ansible' => {
            'openshift-ansible' => 'https://github.com/openshift/openshift-ansible.git'
          }
        }[reponame]
      end

     def self.git_branch_current
        "$(git rev-parse --abbrev-ref HEAD)"
      end

      def self.plugins_conf_dir
        Pathname.new "/plugins"
      end

      def self.sync_dir
        Pathname.new "~/sync"
      end

      def self.build_dir
        Pathname.new "/data/src/github.com/openshift/"
      end

      def self.git_ssh
        Pathname.new(File.expand_path("~/.ssh/vagrant_openshift_ssh_override"))
      end

    end
  end
end
