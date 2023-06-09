#!/bin/bash

# This is intended to be run by a worker node to start a k3s agent.

# Get the login node and secret as variables
login_node=${1}
secret_token=${2}

# Hello server, who are you?
name=$(hostname)
echo "Hello I am ${name} being run by ${USER}"

# See https://github.com/k3s-io/k3s/issues/7333 for why I chose testing channel
echo "Preparing agent node..."
login_address=$(nslookup ${login_node} | grep Address |  sed -n '2 p' |  sed 's/Address: //g')
echo "The login node is ${login_node} at ${login_address}"

# echo "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=testing K3S_URL=https://${login_node}:6443 K3S_TOKEN=xxxxxxxxx sh -"
# curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=testing K3S_URL=https://${login_node}:6443 K3S_TOKEN=${secret_token} sh -
export INSTALL_K3S_CHANNEL=testing 
export K3S_URL=https://${login_node}:6443
export K3S_TOKEN=${secret_token}

# Note the -data-dir should default to this for the server
# systemd-run --user -p Delegate=yes --tty k3s agent --rootless --debug --data-dir=${HOME}/.rancher/k3s/rootless --token=${secret_token} --server=https://${login_address}:6443

# Wait for the node-token to be ready
while [ ! -f $HOME/.rancher/k3s/server/node-token ]
do
  echo "node-token file does not exist yet, waiting"
  sleep 2
done
echo "Found node-token file."

# It doesn't seem to like this one, says the CA Certificate does not match
# token=$(cat $HOME/.rancher/k3s/server/node-token)
k3s agent --rootless --debug --data-dir=${HOME}/.rancher/k3s/rootless --token=${secret_token} --server=https://${login_address}:6443
