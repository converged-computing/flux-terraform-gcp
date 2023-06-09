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

# CHANGE THIS TO SOMETHING DIFFERENT!
secret_token=pancakes-chicken-finger-change-me
login=$(hostname)

# This ensures flux uris are local:// and not ssh://
export FLUX_URI_RESOLVE_LOCAL=t 

# Start an allocation in the background we can then connect to.
echo "The login node for the control plane is ${login}"
flux alloc --bg -N 1 --requires=host:${login} --error ./control-plane.out --output ./control-plane.out bash ./flux_control_plane.sh "${login}" "${secret_token}"

# Get the id so we can connect to the allocation with the the control plane at the end
controljob=$(flux job last)
uri=$(flux uri --local ${controljob})
flux submit -N 2 --requires=-host:${login} --error ./agents.out --output ./agents.out bash ./flux_agent.sh "${login}" "${secret_token}"
echo "To connect: flux proxy ${uri}"
echo "The job with the controller is ${controljob}"
flux proxy $uri bash
flux queue idle

