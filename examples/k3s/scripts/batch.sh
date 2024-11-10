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

# Run this on the main login node - since it's shared we only need 
# to generate the certs once.
if [[ "$nodename" == *"001"* ]]; then

    echo "I am ${nodename} going to run the master stuff"
    /bin/bash ./common/cfssl.sh --dir=/home/$USER/.config/usernetes --master=${node_master} --node=${node_crio} --node=${node_containerd}

    # The script /home/sochat1_llnl_gov/usernetes/boot/kube-proxy.sh is asking for a non-existent 
    # "$XDG_CONFIG_HOME/usernetes/node/kube-proxy.kubeconfig", so we are going to arbitrarily make it
    # I did a diff of the two kube-proxy.kubectl and they are the same
    cp -R ~/.config/usernetes/nodes.$node_crio ~/.config/usernetes/node

    # 2379/tcp: etcd, 6443/tcp: kube-apiserver
    # This first install will timeout because configs are missing, but we need to generate the first ones!
    /bin/bash ./install.sh --wait-init-certs --start=u7s-master-with-etcd.target --cidr=10.0.100.0/24 --publish=0.0.0.0:2379:2379/tcp --publish=0.0.0.0:6443:6443/tcp --cni=flannel --cri=

    # This didn't work the first time
    # systemctl --user start 'u7s-kubelet-crio.service'
    # systemctl --user start 'u7s-kub-proxy.service'
    systemctl --user --all --no-pager list-units 'u7s-*'

    # This is the control plane, so we interact with kubectl here
    echo "KUBECONFIG=$HOME/.config/usernetes/master/admin-localhost.kubeconfig" >> ~/.bashrc
    echo 'PATH=$HOME/usernetes/bin:$PATH' >> ~/.bashrc
    # export KUBECONFIG=/home/sochat1_llnl_gov/.config/usernetes/master/admin-localhost.kubeconfig
    # export PATH=$HOME/usernetes/bin:$PATH
    sudo loginctl enable-linger
fi

# Sleep a little so the node certs are copied
echo "Sleeping a bit because..."
sleep 10

# The first compute node runs crio
if [[ "$nodename" == *"${node_crio}"* ]]; then

    echo "I am compute node ${nodename} going to run crio"
    # 10250/tcp: kubelet, 8472/udp: flannel
    /bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.101.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=crio
    sudo loginctl enable-linger
fi

# The second compute node runs crio
if [[ "$nodename" == *"${node_containerd}"* ]]; then

    echo "I am compute node ${nodename} going to run containerd"

    # 10250/tcp: kubelet, 8472/udp: flannel
    /bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.102.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=containerd
    sudo loginctl enable-linger
fi

# Try to run a dumb loop to ask kubectl for nodes
if [[ "$nodename" == *"001"* ]]; then
  while true
  do
      kubectl get nodes || echo "Cannot get nodes"
      sleep 10
  done
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