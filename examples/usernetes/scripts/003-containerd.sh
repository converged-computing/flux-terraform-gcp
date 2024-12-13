#!/bin/bash

# Final steps to setting up usernetes
# These steps will vary based on the hostname
# Make sure you run the clone step on a node before running this script!
# We need to do this because there is a typo in install.sh
# We also need the node names - not ideal, but for now they are predictable so it works
node_master=gffw-compute-a-001
node_crio=gffw-compute-a-002
node_containerd=gffw-compute-a-003

# What node is running this?
nodename=$(hostname)

# Run from $HOME/usernetes
cd ~/usernetes

systemctl --user daemon-reload
uid=$(basename $XDG_RUNTIME_DIR)

# NOTE this shouldn't need to be done but it's a hack for now
# when I don't do this the containerd sock does not write
sudo chown -R $USER /sys/fs/cgroup/user.slice/user-${uid}.slice

# Sleep a little so the node certs are copied
echo "Sleeping a bit because..."
sleep 10

echo "I am compute node ${nodename} going to run containerd"

# 10250/tcp: kubelet, 8472/udp: flannel
/bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.102.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=containerd
sudo loginctl enable-linger