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

echo "I am ${nodename} going to run the master stuff"
/bin/bash ./common/cfssl.sh --dir=/home/$USER/.config/usernetes --master=${node_master} --node=${node_crio} --node=${node_containerd}

# The script /home/sochat1_llnl_gov/usernetes/boot/kube-proxy.sh is asking for a non-existent 
# "$XDG_CONFIG_HOME/usernetes/node/kube-proxy.kubeconfig", so we are going to arbitrarily make it
# I did a diff of the two kube-proxy.kubectl and they are the same
cp -R ~/.config/usernetes/nodes.$node_crio ~/.config/usernetes/node
    
# This is mentioned in the kube-config.yaml and does not exist
mkdir -p ~/.local/share/usernetes/kubelet-plugins-exec

# 2379/tcp: etcd, 6443/tcp: kube-apiserver
# This first install will timeout because configs are missing, but we need to generate the first ones!
/bin/bash ./install.sh --wait-init-certs --start=u7s-master-with-etcd.target --cidr=10.0.100.0/24 --publish=0.0.0.0:2379:2379/tcp --publish=0.0.0.0:6443:6443/tcp --cni=flannel --cri=

# This is the control plane, so we interact with kubectl here
echo "KUBECONFIG=$HOME/.config/usernetes/master/admin-localhost.kubeconfig" >> ~/.bashrc
echo 'PATH=$HOME/usernetes/bin:$PATH' >> ~/.bashrc
# export KUBECONFIG=/home/sochat1_llnl_gov/.config/usernetes/master/admin-localhost.kubeconfig
# export PATH=$HOME/usernetes/bin:$PATH
sudo loginctl enable-linger