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
    pmix \
    pmix-devel \
    lua \
    lua-devel \
    lua-posix \
    libevent-devel \
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

# IMPORTANT: the flux user/group must match!
# useradd -M -r -s /bin/false -c "flux-framework identity" flux
groupadd -g 1004 flux
useradd -u 1004 -g 1004 -M -r -s /bin/false -c "flux-framework identity" flux

# Update grub
# cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
# sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
# update-grub

dnf install -y grubby 
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"

cd /usr/share

# These versions are chosen to match the demo container
git clone -b v0.49.0 https://github.com/flux-framework/flux-core.git
git clone -b v0.27.0 https://github.com/flux-framework/flux-sched.git
git clone -b v0.7.0 https://github.com/flux-framework/flux-security.git
git clone -b v0.3.0 https://github.com/flux-framework/flux-pmix.git

cd /usr/share/flux-security

./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc

make
make install

cd /usr/share/flux-core

# Important - if PKGCONFIG is used here it seems to default to /usr/local
# and I don't think we want this
./autogen.sh
./configure --prefix=/usr --with-flux-security --sysconfdir=/etc

make -j 8
make install

cd /usr/share/flux-sched

./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc

make
make install

# Install openpmix, prrte (for flux-pmix)
git clone https://github.com/openpmix/openpmix.git /opt/openpmix
git clone https://github.com/openpmix/prrte.git /opt/prrte
cd /opt/openpmix
git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93
./autogen.pl
./configure --prefix=/usr --disable-static && make -j 4 install
ldconfig 
cd /opt/prrte
git checkout 477894f4720d822b15cab56eee7665107832921c
./autogen.pl
./configure --prefix=/usr && make -j 4 install

cd /usr/share/flux-pmix

./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc

make
make install

# IMPORANT: the above installs to /usr/lib64 but you will get a flux_open error if it's
# not found in /usr/lib. So we put in both places :)
cp -R /usr/lib64/flux /usr/lib/flux
cp -R /usr/lib64/libflux-* /usr/lib/

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
