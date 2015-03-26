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
      class RunOpenshift3Tests
        include CommandHelper

        @@SSH_TIMEOUT = 4800

        def initialize(app, env, options)
          @app = app
          @env = env
          @options = options.clone
        end

        def run_tests(env, cmds, as_root=true)
          tests = ''
          cmds.each do |cmd|
            tests += "
echo '***************************************************'
echo 'Running #{cmd}...'
time #{cmd}
echo 'Finished #{cmd}'
echo '***************************************************'
"
          end
          cmd = %{
set -e
pushd #{Constants.build_dir}/origin >/dev/null
export PATH=$GOPATH/bin:$PATH
#{tests}
popd >/dev/null
        }
          exit_code = 0
          if as_root
            _,_,exit_code = sudo(env[:machine], cmd, {:timeout => 60*60, :fail_on_error => false, :verbose => false})
          else
            _,_,exit_code = do_execute(env[:machine], cmd, {:timeout => 60*60, :fail_on_error => false, :verbose => false})
          end
          exit_code
        end

        #
        # Build and run the make commands
        #   for testing all run make test
        #   for testing unit tests only run make build check
        #   for testing assets run hack/test-assets.sh
        #
        # All env vars will be added to the beginning of the command like VAR=1 make test
        #
        def call(env)
          @options.delete :logs
          cmd_env = []
          build_targets = ["make"]
          test_run = false

          if @options[:assets] || @options[:all]
            cmd_env << 'TEST_ASSETS=true'
          end

          if @options[:integration] || @options[:extended] || @options[:all]
            cmd_env << 'ARTIFACT_DIR=/tmp/origin/e2e/artifacts'
            cmd_env << 'LOG_DIR=/tmp/origin/e2e/logs'
            build_targets << 'test'
            # we want to test the output of build-release, this flag tells
            # the makefile to skip the build dependency
            # so the command comes out to <cmd_env settings> make test SKIP_BUILD=true
            build_targets << "SKIP_BUILD=true"
            test_run = true
          end

          # If we run 'make test' the 'check' is always called so there is no
          # reason to execute it twice.
          # The '--unit' option is valid only when no --integration or
          # --extended are present
          if @options[:unit] && !test_run
            build_targets << 'check'
          end

          if @options[:skip_image_cleanup]
            cmd_env << 'SKIP_IMAGE_CLEANUP=1'
          end

          if @options[:report_coverage]
            cmd_env << 'OUTPUT_COVERAGE=/tmp/origin/e2e/artifacts/coverage'
          end

          if @options[:extended] || @options[:all]
            cmd_env << 'EXTENDED=true'
          end

          cmd = cmd_env.join(' ') + ' ' + build_targets.join(' ')
          env[:test_exit_code] = run_tests(env, [cmd], true)

          # any other tests that should not be run as sudo
          if env[:test_exit_code] == 0 && (@options[:assets] || @options[:all])
            cmds = ['hack/test-assets.sh']
            env[:test_exit_code] = run_tests(env, cmds, false)
          end

          @app.call(env)
        end
      end
    end
  end
end
