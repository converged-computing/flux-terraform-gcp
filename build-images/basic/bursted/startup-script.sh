cat << "EOF" >> /etc/yum.repos.d/gcsfuse.repo
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

dnf update -y
dnf clean all

dnf group install -y "Development Tools"

dnf config-manager --set-enabled powertools
dnf install -y epel-release

dnf install -y \
    munge \
    munge-devel \
    hwloc \
    hwloc-devel \
    lua \
    lua-devel \
    lua-posix \
    czmq-devel \
    jansson-devel \
    lz4-devel \
    sqlite-devel \
    ncurses-devel \
    libarchive-devel \
    libxml2-devel \
    yaml-cpp-devel \
    boost-devel \
    libedit-devel \
    nfs-utils \
    python36-devel \
    python3-cffi \
    python3-yaml \
    python3-jsonschema \
    python3-sphinx \
    python3-docutils \
    aspell \
    aspell-en \
    valgrind-devel \
    openmpi.x86_64 \
    openmpi-devel.x86_64 \
    gcsfuse \
    jq

useradd -M -r -s /bin/false -c "flux-framework identity" flux

# Update grub
# cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
# sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
# update-grub

dnf install -y grubby 
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"

cd /usr/share

git clone -b v0.49.0 https://github.com/flux-framework/flux-core.git
git clone -b v0.27.0 https://github.com/flux-framework/flux-sched.git
git clone -b v0.8.0 https://github.com/flux-framework/flux-security.git
git clone -b v0.3.0 https://github.com/flux-framework/flux-pmix.git

cd /usr/share/flux-security

./autogen.sh
./configure --prefix=/usr

make
make install

cd /usr/share/flux-core

./autogen.sh
PKG_CONFIG_PATH=$(pkg-config --variable pc_path pkg-config)
PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH
PKG_CONFIG_PATH=${PKG_CONFIG_PATH} ./configure --prefix=/usr --with-flux-security

make -j 8
make install

cd /usr/share/flux-sched

./autogen.sh
./configure --prefix=/usr

make
make install

cd /usr/share/flux-pmix

./autogen.sh
./configure --prefix=/usr

make
make install

# A quick Python script for handling decoding
cat << "PYTHON_DECODING_SCRIPT" > /etc/flux/manager/convert_munge_key.py
#!/usr/bin/env python3

import sys
import base64

string = sys.argv[1]
dest = sys.argv[2]
encoded = string.encode('utf-8')
with open(dest, 'wb') as fd:
    fd.write(base64.b64decode(encoded))
PYTHON_DECODING_SCRIPT

echo "/usr/etc/flux/imp *(rw,no_subtree_check,no_root_squash)" >> /etc/exports
echo "/usr/etc/flux/security *(rw,no_subtree_check,no_root_squash)" >> /etc/exports
echo "/usr/etc/flux/system *(rw,no_subtree_check,no_root_squash)" >> /etc/exports
echo "/etc/munge *(rw,no_subtree_check,no_root_squash)" >> /etc/exports

systemctl enable nfs-server
