#--
# Copyright 2015 Red Hat, Inc.
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
require 'open-uri'
require 'openssl'
require 'uri'

module Vagrant
  module Openshift
    module Action
      class WaitForOpenshift3
        include CommandHelper

        def initialize(app, env)
          @app = app
          @env = env
        end

        def call(env)
          puts 'Waiting on origin...'

          uri    = URI.parse('https://localhost:8443/api')
          status = nil
          begin
            until '200' == status
              uri.open(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, read_timeout: 10) do |response|
                status = response.status[0]
                if '200' == status
                  puts "...#{response.status[1]}"
                else
                  puts "...#{response.status[1]}:#{status}"
                  sleep 1
                end
              end
            end
          rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET, OpenURI::HTTPError
            sleep 1
            retry
          rescue => e
            puts "#{e.class}: #{e.message}"
            exit
          end

          @app.call(env)
        end
      end
    end
  end
end
