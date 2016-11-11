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
      class InstallOriginBaseDependencies
        include CommandHelper

        def initialize(app, env)
          @app = app
          @env = env
        end

        def call(env)
          # Workaround to vagrant inability to guess interface naming sequence
          # Tell system to abandon the new naming scheme and use eth* instead
          is_fedora = env[:machine].communicate.test("test -e /etc/fedora-release")
          if is_fedora
            sudo(env[:machine], %{
if ! [[ -L /etc/udev/rules.d/80-net-setup-link.rules ]]; then
  ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
  rm -f /etc/sysconfig/network-scripts/ifcfg-enp0s3
fi
            }, :verbose => false)
          end


          sudo(env[:machine], %{
if [[ -e /etc/redhat-release && ! -e /etc/fedora-release && ! -e /etc/centos-release ]]; then

cat <<EOF > /etc/yum.repos.d/dockerextra.repo
[dockerextra]
name=RHEL Docker Extra
baseurl=https://mirror.openshift.com/enterprise/rhel/dockerextra/x86_64/os/
enabled=1
gpgcheck=0
failovermethod=priority
sslverify=False
sslclientcert=/var/lib/yum/client-cert.pem
sslclientkey=/var/lib/yum/client-key.pem

EOF

fi
          }, :timeout=>60*10, :verbose => false)

          ssh_user = env[:machine].ssh_info[:username]
          sudo(env[:machine], "yum install -y \
                                augeas \
                                bsdtar \
                                bzr \
                                bridge-utils \
                                bzip2 \
                                bind \
                                btrfs-progs-devel \
                                bind-utils \
                                ctags \
                                device-mapper-devel \
                                docker-io \
                                ethtool \
                                e2fsprogs \
                                fontconfig \
                                git \
                                gcc \
                                gcc-c++ \
                                glibc-static \
                                gnuplot \
                                httpie \
                                hg \
                                iscsi-initiator-utils \
                                jq \
                                java-1.?.0-openjdk \
                                kernel-devel \
                                krb5-devel \
                                libselinux-devel \
                                libnetfilter_queue-devel \
                                lsof \
                                make \
                                mlocate \
                                ntp \
                                openldap-clients \
                                openvswitch \
                                rubygems \
                                screen \
                                ShellCheck \
                                socat \
                                sqlite-devel \
                                strace \
                                sysstat \
                                tcpdump \
                                tig \
                                tmux \
                                unzip \
                                zip \
                                vim \
                                wget \
                                xfsprogs \
                                xorg-x11-utils \
                                Xvfb \
                                firefox \
                                yum-utils",:timeout=>60*30, :verbose => false)

          sudo(env[:machine], "yum install -y facter", fail_on_error: false, :timeout=>60*20, :verbose => false)

          # Install Chrome and chromedriver for headless UI testing
          sudo(env[:machine], %{
set -ex
cd /tmp

# Add signing key for Chrome repo
wget https://dl.google.com/linux/linux_signing_key.pub
rpm --import linux_signing_key.pub

# Add Chrome yum repo
yum-config-manager --add-repo=http://dl.google.com/linux/chrome/rpm/stable/x86_64

# Install chrome
yum install -y google-chrome-stable

# Install chromedriver
wget https://chromedriver.storage.googleapis.com/2.16/chromedriver_linux64.zip
unzip chromedriver_linux64.zip
mv chromedriver /usr/bin/chromedriver
chown root /usr/bin/chromedriver
chmod 755 /usr/bin/chromedriver
          }, :timeout=>60*60, :verbose => false)

          sudo(env[:machine], "wget -O /etc/yum.repos.d/openshift-rhel7-dependencies.repo https://mirror.openshift.com/pub/openshift-origin/nightly/rhel-7/dependencies/openshift-rhel7-dependencies.repo", fail_on_error: true, :timeout=>60*20, :verbose => true)

          #
          # FIXME: Need to install golang packages 'after' the 'gcc' is
          #        installed. See BZ#1101508
          #
          sudo(env[:machine], "yum install -y golang golang-src", :timeout=>60*20, :verbose => false)
          #

          unless is_fedora
            sudo(env[:machine], "yum install -y golang-pkg-linux-amd64", :timeout=>60*20, :verbose => false)
          end

          sudo(env[:machine], %{
set -ex

if [[ ! -e /etc/fedora-release ]]; then
curl -s  https://mirror.openshift.com/mirror/epel/epel7.repo > /etc/yum.repos.d/epel-openshift.repo
echo 'OS_BUILD_IMAGE_ARGS="--mount /etc/yum.repos.d/epel-openshift.repo:/etc/yum.repos.d/epel.repo"' >> /etc/environment
fi

if [[ -e /etc/redhat-release && ! -e /etc/fedora-release && ! -e /etc/centos-release ]]; then

# create rhaos3.1 and 3.2 repos
cat <<EOF > /etc/yum.repos.d/rhaos31.repo
[rhel-7-server-ose-3.1-rpms]
name=RHEL7 Red Hat Atomic OpenShift 3.1
baseurl=https://mirror.ops.rhcloud.com/enterprise/enterprise-3.1/RH7-RHAOS-3.1/x86_64/os/
        https://use-mirror1.ops.rhcloud.com/enterprise/enterprise-3.1/RH7-RHAOS-3.1/x86_64/os/
        https://use-mirror2.ops.rhcloud.com/enterprise/enterprise-3.1/RH7-RHAOS-3.1/x86_64/os/
        https://euw-mirror1.ops.rhcloud.com/enterprise/enterprise-3.1/RH7-RHAOS-3.1/x86_64/os/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release,file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta,https://mirror.ops.rhcloud.com/libra/keys/RPM-GPG-KEY-redhat-openshifthosted
failovermethod=priority
sslverify=0
sslclientcert=/var/lib/yum/client-cert.pem
sslclientkey=/var/lib/yum/client-key.pem

EOF


cat <<EOF > /etc/yum.repos.d/rhaos32.repo
[rhel-7-server-ose-3.2-rpms]
name=RHEL7 Red Hat Atomic OpenShift 3.2
baseurl=https://mirror.ops.rhcloud.com/enterprise/enterprise-3.2/latest/RH7-RHAOS-3.2/x86_64/os/
        https://use-mirror1.ops.rhcloud.com/enterprise/enterprise-3.2/latest/RH7-RHAOS-3.2/x86_64/os/
        https://use-mirror2.ops.rhcloud.com/enterprise/enterprise-3.2/latest/RH7-RHAOS-3.2/x86_64/os/
        https://euw-mirror1.ops.rhcloud.com/enterprise/enterprise-3.2/latest/RH7-RHAOS-3.2/x86_64/os/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release,file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta,https://mirror.ops.rhcloud.com/libra/keys/RPM-GPG-KEY-redhat-openshifthosted
failovermethod=priority
sslverify=0
sslclientcert=/var/lib/yum/client-cert.pem
sslclientkey=/var/lib/yum/client-key.pem

EOF

cat <<EOF > /etc/yum.repos.d/rhaos33.repo
[rhel-7-server-ose-3.3-rpms]
name=RHEL7 Red Hat Atomic OpenShift 3.3
baseurl=https://mirror.ops.rhcloud.com/enterprise/enterprise-3.3/latest/RH7-RHAOS-3.3/x86_64/os/
        https://use-mirror1.ops.rhcloud.com/enterprise/enterprise-3.3/latest/RH7-RHAOS-3.3/x86_64/os/
        https://use-mirror2.ops.rhcloud.com/enterprise/enterprise-3.3/latest/RH7-RHAOS-3.3/x86_64/os/
        https://euw-mirror1.ops.rhcloud.com/enterprise/enterprise-3.3/latest/RH7-RHAOS-3.3/x86_64/os/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release,file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta,https://mirror.ops.rhcloud.com/libra/keys/RPM-GPG-KEY-redhat-openshifthosted
failovermethod=priority
sslverify=0
sslclientcert=/var/lib/yum/client-cert.pem
sslclientkey=/var/lib/yum/client-key.pem

EOF

cat <<EOF > /etc/yum.repos.d/rhaos34.repo
[rhel-7-server-ose-3.4-rpms]
name=RHEL7 Red Hat Atomic OpenShift 3.4
baseurl=https://mirror.ops.rhcloud.com/enterprise/enterprise-3.4/latest/RH7-RHAOS-3.4/x86_64/os/
        https://use-mirror1.ops.rhcloud.com/enterprise/enterprise-3.4/latest/RH7-RHAOS-3.4/x86_64/os/
        https://use-mirror2.ops.rhcloud.com/enterprise/enterprise-3.4/latest/RH7-RHAOS-3.4/x86_64/os/
        https://euw-mirror1.ops.rhcloud.com/enterprise/enterprise-3.4/latest/RH7-RHAOS-3.4/x86_64/os/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release,file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta,https://mirror.ops.rhcloud.com/libra/keys/RPM-GPG-KEY-redhat-openshifthosted
failovermethod=priority
sslverify=0
sslclientcert=/var/lib/yum/client-cert.pem
sslclientkey=/var/lib/yum/client-key.pem

EOF

fi

if ! test -e /etc/fedora-release; then
  sed -i 's,^SELINUX=.*,SELINUX=permissive,' /etc/selinux/config
  setenforce 0
fi

systemctl enable ntpd

groupadd -f docker
usermod -a -G docker #{ssh_user}

ADDITIONAL_OPTIONS='--insecure-registry=172.30.0.0/16 --insecure-registry=ci.dev.openshift.redhat.com:5000'
sed -i "s,^OPTIONS='\\(.*\\)',OPTIONS='${ADDITIONAL_OPTIONS} \\1'," /etc/sysconfig/docker
sed -i "s,^OPTIONS=-\\(.*\\),OPTIONS='${ADDITIONAL_OPTIONS} -\\1'," /etc/sysconfig/docker
sed -i "s,^ADD_REGISTRY='\\(.*\\)',#ADD_REGISTRY='--add-registry=docker.io \\1'," /etc/sysconfig/docker

cat /etc/sysconfig/docker


if sudo lvdisplay docker-vg 2>&1>/dev/null
then
  VG="docker-vg"
elif sudo lvdisplay vg_vagrant 2>&1>/dev/null
then
  VG="vg_vagrant"
elif sudo lvdisplay fedora 2>&1>/dev/null
then
  VG="fedora"
elif sudo lvdisplay centos 2>&1>/dev/null
then
  VG="centos"
fi
if [ -n "${VG}" ]
then
  sudo lvcreate -n docker-data -l 70%FREE /dev/${VG}
  sudo lvcreate -n docker-metadata -l 17%FREE /dev/${VG}
  sudo sed -i "s,^DOCKER_STORAGE_OPTIONS=.*,DOCKER_STORAGE_OPTIONS='-s devicemapper --storage-opt dm.datadev=/dev/${VG}/docker-data --storage-opt dm.metadatadev=/dev/${VG}/docker-metadata --storage-opt dm.use_deferred_removal=true --storage-opt dm.use_deferred_deletion=true'," /etc/sysconfig/docker-storage

  sudo lvcreate -n openshift-xfs-vol-dir -l 100%FREE /dev/${VG}
  sudo mkfs.xfs /dev/${VG}/openshift-xfs-vol-dir
  sudo mkdir -p /mnt/openshift-xfs-vol-dir
  sudo sh -c "echo /dev/${VG}/openshift-xfs-vol-dir /mnt/openshift-xfs-vol-dir xfs gquota 1 1 >> /etc/fstab"
  sudo mount /mnt/openshift-xfs-vol-dir
  sudo chown -R #{ssh_user}:#{ssh_user} /mnt/openshift-xfs-vol-dir
fi

# Force socket reuse
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

mkdir -p /data/src
mkdir -p /data/pkg
mkdir -p /data/bin

GO_VERSION=($(go version))
echo "Detected go version: $(go version)"

# TODO: Remove for go1.5, go vet and go cover will be internal
if [[ ${GO_VERSION[2]} == "go1.4"* ]]; then
  GOPATH=/data go get golang.org/x/tools/cmd/cover

# https://groups.google.com/forum/#!topic/golang-nuts/nZLhcbaa3wQ
set +e
  GOPATH=/data go get golang.org/x/tools/cmd/vet
set -e

  # Check out a stable commit for go vet in order to version lock it to something we can work with
  pushd /data/src/golang.org/x/tools >/dev/null
    if git checkout 108746816ddf01ad0c2dbea08a1baef08bc47313
    then
      # Re-install using this version of the tool
      GOPATH=/data go install golang.org/x/tools/cmd/vet
    fi
  popd >/dev/null
fi

chown -R #{ssh_user}:#{ssh_user} /data

sed -i "s,^#DefaultTimeoutStartSec=.*,DefaultTimeoutStartSec=240s," /etc/systemd/system.conf

# Docker 1.8.2 now sets a TimeoutStartSec of 1 minute.  Unfortunately, for some
# reason the initial docker start up is now taking > 5 minutes.  Until that is fixed need this.
sed -i 's,TimeoutStartSec=.*,TimeoutStartSec=10min,'  /usr/lib/systemd/system/docker.service

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable docker
time systemctl start docker
          }, :timeout=>60*30, :verbose => false)
          @app.call(env)
        end
      end
    end
  end
end
