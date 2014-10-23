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
      class InstallOpenshift3
        include CommandHelper
        def initialize(app, env)
          @app = app
          @env = env
        end

        def call(env)
          ssh_user = env[:machine].ssh_info[:username]
          sudo(env[:machine], %{
set -x
# TODO Remove me ASAP
sed -i 's,^SELINUX=.*,SELINUX=permissive,' /etc/selinux/config
setenforce 0
usermod -a -G docker #{ssh_user}

ORIGIN_PATH=/data/src/github.com/openshift/origin

cat > /etc/profile.d/openshift.sh <<DELIM
export GOPATH=/data
export PATH=$GOPATH/bin:$ORIGIN_PATH/_output/etcd/bin:$ORIGIN_PATH/_output/go/bin:$PATH
DELIM

source /etc/profile.d/openshift.sh

go get code.google.com/p/go.tools/cmd/cover

pushd $ORIGIN_PATH
  hack/install-etcd.sh
popd

# Force socket reuse
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
# Force using local images instead of always reaching docker hub when doing builds
export USE_LOCAL_IMAGES=true

chown -R #{ssh_user}:#{ssh_user} /data

cat > /usr/lib/systemd/system/openshift.service <<DELIM
[Unit]
Description=OpenShift
After=docker.service
Requires=docker.service
Documentation=https://github.com/openshift/origin

[Service]
Type=simple
EnvironmentFile=-/etc/default/openshift
ExecStart=$ORIGIN_PATH/_output/go/bin/openshift start

[Install]
WantedBy=multi-user.target
DELIM

#systemctl enable openshift.service
          })

          @app.call(env)
        end
      end
    end
  end
end
