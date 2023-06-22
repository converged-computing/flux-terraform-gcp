#!/bin/bash

# Final steps to setting up usernetes
# These steps will vary based on the hostname

# Hard code my username for now :)
user=${USER:-sochat1_llnl_gov}

# We also need the node names - not ideal, but for now they are predictable so it works
node_crio=gffw-compute-a-001
node_containerd=gffw-compute-a-002
node_master=gffw-login-001

# What node is running this?
nodename=$(hostname)

# Install usernetes and fuse3 on all nodes
sudo dnf install -y wget fuse3
wget https://github.com/rootless-containers/usernetes/releases/download/v20230518.0/usernetes-x86_64.tbz
tar xjvf usernetes-x86_64.tbz
cd usernetes

# Run this on the main login node - since it's shared we only need 
# to generate the certs once.
if [[ "$nodename" == *"login"* ]]; then

    echo "I am the login node ${nodename} going to run the master stuff"
    /bin/bash ./common/cfssl.sh --dir=/home/$USER/.config/usernetes --master=${node_master} --node=${node_crio} --node=${node_containerd}

    # 2379/tcp: etcd, 6443/tcp: kube-apiserver
    /bin/bash ./install.sh --wait-init-certs --start=u7s-master-with-etcd.target --cidr=10.0.100.0/24 --publish=0.0.0.0:2379:2379/tcp --publish=0.0.0.0:6443:6443/tcp --cni=flannel --cri=

fi

# The first compute node runs crio
if [[ "$nodename" == *"${node_crio}"* ]]; then

    echo "I am the 1st compute node ${nodename} going to run crio"
    # 10250/tcp: kubelet, 8472/udp: flannel
    /bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.101.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=crio

fi

# The second compute node runs crio
if [[ "$nodename" == *"${node_containerd}"* ]]; then

    echo "I am the 2nd compute node ${nodename} going to run containerd"

    # 10250/tcp: kubelet, 8472/udp: flannel
    /bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.102.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=containerd

fi

# Bind utils has nslookup to get ip address
# dnf update -y 
# dnf install -y wget bind-utils
# dnf install -q -y conntrack findutils fuse3 git iproute iptables hostname procps-ng time which jq

# dnf -y install dnf-plugins-core

# dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install docker just to install usernetes binaries
# dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# systemctl start docker
# systemctl enable docker
# sudo usermod -aG docker $(whoami)
