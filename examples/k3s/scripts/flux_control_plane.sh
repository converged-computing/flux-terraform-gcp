#!/bin/bash

# This is intended to be run by the login (main control plane) node

# Get the login node and secret as variables
login_node=${1}
secret_token=${2}

# Hello server, who are you?
name=$(hostname)
echo "Hello I am ${name} being run by ${USER}"

# ~/.config/systemd/user/k3s-rootless.service should exist!

# Ensure KUBECONFIG is exported
function ensure_kubeconfig {
    path=${1}

    # We only care if the file exists
    if [[ -f "$path" ]]; then
        echo "Checking for KUBECONFIG defined in $path..."
        cat ${path} | grep "export KUBECONFIG" >> /dev/null
        retval=$?
        if [[ $retval -ne 0 ]]; then
            echo "KUBECONFIG not found in ${path}, adding."
            echo "export KUBECONFIG=~/.kube/config" >> ${path}
        else
            echo "KUBECONFIG is already defined in ${path}."
        fi
        cat ${path} | grep KUBECONFIG
    fi
}
    
# We might be able to do this (no, requires sudo)
# curl -sfL https://get.k3s.io | K3S_TOKEN=${secret_token} sh -
export K3S_TOKEN=${secret_token}
export KUBECONFIG=~/.kube/config
mkdir -p ~/.kube

# Get the kubeconfig to use, if not set in profiles, set
# chmod 600 "$KUBECONFIG"
ensure_kubeconfig "~/.profile"
ensure_kubeconfig "~/.bash_profile"

# Reload!
systemctl --user daemon-reload
systemctl --user enable --now k3s-rootless

# Enter the interactive session (otherwise the alloc will exit)
bash
