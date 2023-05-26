#!/bin/bash

# This is a flux job that can be given to the main broker to launch the k3s cluster
# under flux. It handles installing and starting the rootless service, and
# starting the control plane and agents under the worker nodes. We only have
# three nodes total (2 compute and 1 login) so our cluster is very small for now :)
# To run this on a three node cluster:

# gcloud compute scp --zone us-central1-a ./scripts/flux_job.sh gffw-login-001:/tmp/flux_job.sh
# flux start flux submit -N 3 /bin/bash flux_job.sh

# To adapt this you should:

# 1. Ensure the secret is not hard coded
# 2. Update the node names to correspond to a cluster (and likely you'd programmatically generate)
# 3. Decide if you want to really define KUBECONFIG in their bash profile (maybe not)
# 4. Decide if you want to run the install script every time - likely  you want to install and then just start with the job
# 5. The install needs to be done apriori so the config doesn't need to be copied from /etc/rancher (requires sudo)
# 6. if you just wget the install script, it likely needs to broken up into pieces for installing (requires sudo) vs. init-ing.
# 7. Adopt further to be run on HPC, of course :)

# although there is a hard coded "secret token" here, you would

# CHANGE THIS TO SOMETHING DIFFERENT!
export secret_token=pancakes-chicken-finger-change-me

# Hello server, who are you?
name=$(hostname)
echo "Hello I am ${name} being run by ${USER}"

### k3s (master node) vs worker
if [[ "${name}" == "gffw-login-001" ]]; then

    mkdir -p ~/.config/systemd/user

    if [[ ! -f "~/.config/systemd/user/k3s-rootless.service" ]]; then
        echo "Retrieving k3s-rootless.service..."
        wget -O ~/.config/systemd/user/k3s-rootless.service https://raw.githubusercontent.com/k3s-io/k3s/master/k3s-rootless.service
        
    fi
    
    # We might be able to do this?
    curl -sfL https://get.k3s.io | K3S_TOKEN=${secret_token} sh -

    export KUBECONFIG=~/.kube/config
    mkdir -p ~/.kube

    # TODO double check if this config is correct for rootless mode!
    # IMPORTANT: this is why you need to have something setup apriori -
    # the user obviously cannot have sudo!
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown -R $USER ~/.kube

    # Get the kubeconfig to use
    # chmod 600 "$KUBECONFIG"
    echo "export KUBECONFIG=~/.kube/config" >> ~/.profile
    echo "export KUBECONFIG=~/.kube/config" >> ~/.bash_profile

    # Reload!
    systemctl --user daemon-reload
    systemctl --user enable --now k3s-rootless

else
    # See https://github.com/k3s-io/k3s/issues/7333 for why I chose testing channel
    echo "Preparing agent node..."
    login_node=$(nslookup gffw-compute-a-001 | grep Address |  sed -n '2 p' |  sed 's/Address: //g')
    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=testing K3S_URL=https://${login_node}:6443 K3S_TOKEN=${secret_token} sh -
fi

# Enter the interactive session (otherwise the alloc will exit)
/bin/bash

# if you need to debug
# journalctl --user -f -u k3s-rootless

# Now you can get nodes:
# kubectl get nodes
