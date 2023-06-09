# Basic Flux Framework on GCP

This deployment illustrates deploying a flux-framework cluster on GCP.
All components are included here.

# Usage

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images)
Initialize the deployment with the command:

```bash
$ terraform init
```

I find it's easier to export my Google project in the parent environment for nested terraform configs.

```bash
export GOOGLE_PROJECT=$(gcloud config get-value core/project)
```

## K3s

The way this works is that we are running some setup commands in [scripts/install_k3s.sh](scripts/install_k3s.sh)
and others will be done by the user. Mapping this to an HPC cluster, you'd want to have the same separation
of commands that are done in advance, vs. when the job is done. See the [script header](scripts/flux_job.sh)
for the recommended changes I'd make. You'll want to inspect k3s.tfvars and change for your use case. Then:

```bash
$ make
```

And inspect the [Makefile](Makefile) to see the terraform commands we apply
to init, format, validate, and deploy. The deploy will setup networking and all the instances! Note that
you can change any of the `-var` values to be appropriate for your environment.
Before you shell in, copy the flux job files (to launch and install k3s):

```bash
# Copy over flux batch scripts
gcloud compute scp --zone us-central1-a ./scripts/flux_batch.sh gffw-login-001:~/flux_batch.sh
gcloud compute scp --zone us-central1-a ./scripts/flux_agent.sh gffw-login-001:~/flux_agent.sh
gcloud compute scp --zone us-central1-a ./scripts/flux_control_plane.sh gffw-login-001:~/flux_control_plane.sh

# We will need to copy this into a different location
gcloud compute scp --zone us-central1-a ./scripts/k3s-rootless.service gffw-login-001:~/k3s-rootless.service
```

After it's done creating and you've copied the file, shell in to verify that the cluster is up:

```bash
$ gcloud compute ssh gffw-login-001 --zone us-central1-a
```

Put the service file in the right spot:

```bash
mkdir -p ~/.config/systemd/user
mv ./k3s-rootless.service ~/.config/systemd/user/k3s-rootless.service
```

You should see your three job files in your home now:

```bash
$ ls
flux_agent.sh  flux_batch.sh  flux_control_plane.sh
```

Check that the cluster is up and working!

```bash
$ flux resource list
```
```console
     STATE PROPERTIES NNODES   NCORES NODELIST
      free x86-64,e2       1        2 gffw-login-001
      free x86-64,c2       2       16 gffw-compute-a-[001-002]
 allocated                 0        0 
      down                 0        0 
```
```bash
$ flux run -N 3 hostname
```
```console
gffw-login-001
gffw-compute-a-001
gffw-compute-a-002
```

k3s should also already be installed:

```bash
$ which k3s
/usr/local/bin/k3s
```

For Google cloud, I noticed a bug it was adding my local username as the uid/gid, and
if you don't have the same in both places, you'll need to update this. E.g.,
ensure the name in the first line of these two files is your `$USER`

```
cat /etc/subuid
cat /etc/subgid
```

Yes! Next we want to run our batch job that will install k3s and run the agent / service.
The batch job will write output for each of the agents and control plane locally,
and run the control plane as an allocation to connect you to at the end.

```bash
$ flux batch -N 3 ./flux_batch.sh
```

For debugging, if you shell into a worker node (and you are outside the allocation
running) you should be able to see it:

```bash
$ flux jobs -a
```
```console
       JOBID USER     NAME       ST NTASKS NNODES     TIME INFO
   ƒ56GUEWMD vsochat_ ./flux_ba+  R      3      3   7.960s gffw-login-001,gffw-compute-a-[001-002]
```

You'll want to look at the batch output to connect to the control plane:

```bash
$ cat flux-ƒavGzQKrP.out 
```
```console
The login node for the control plane is gffw-login-001
ƒQpjTeP
ƒobgRjd
To connect: flux proxy local:///tmp/flux-WvrGnh/local-0
The job with the controller is ƒQpjTeP
```

E.g.,

```bash
$ flux proxy local:///tmp/flux-WvrGnh/local-0
```

Once you have an interactive shell in the allocation, you should see the resources available to you:

```bash
$ flux resource list
```
```console
$  flux resource list
     STATE PROPERTIES NNODES   NCORES NODELIST
      free x86-64,e2       1        2 gffw-login-001
      free x86-64,c2       2       16 gffw-compute-a-[001-002]
 allocated                 0        0 
      down                 0        0 
```

Next we need the kubeconfig (and I haven't figured out a solution for this) you'll need to copy the rancher
kube config over:

```bash
sudo cp /etc/rancher/k3s/k3s.yaml 
sudo chown -R $USER $HOME/.kube
```

Obviously a user cannot do this (requires sudo) but we need to figure out a way to do
it. I tried adding variables to start to do it, but it seemed to create a weird empty symlink
instead and didn't work yet. I opened an issue [here](https://github.com/k3s-io/k3s/discussions/7615).

```bash
$ kubectl --kubeconfig=$HOME/.kube/config get nodes
```
```console
$ kubectl --kubeconfig=$HOME/.kube/config get nodes
NAME             STATUS   ROLES                  AGE   VERSION
gffw-login-001   Ready    control-plane,master   76m   v1.26.4+k3s1
```

That indicates the master is ready. I haven't figured out the correct command for the agents to connect -
issue and discussion is [here](https://github.com/k3s-io/k3s/discussions/7615#discussioncomment-6015834).
Note that if we just ran this as the install script with sudo, it would connect fine 
(see the [Flux Operator example](https://github.com/flux-framework/flux-operator/tree/main/examples/nested/k3s/basic))
where we do this same workflow to start the control plane and workers under flux and have
a working cluster.

If you "force it" and run the install script with sudo, it does seem to work:

```bash
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE   VERSION
gffw-compute-a-001   Ready    <none>                 17m   v1.26.4+k3s1
gffw-login-001       Ready    control-plane,master   42m   v1.26.4+k3s1
gffw-compute-a-002   Ready    <none>                 1s    v1.27.2-rc3+k3s1
```

Which I did by doing the following (on each of the agent nodes):

```bash
export secret_token=pancakes-chicken-finger-change-me

# Note the login node hostname is hard coded here!!
login_node=$(nslookup gffw-login-001 | grep Address |  sed -n '2 p' |  sed 's/Address: //g')
echo "Login node is ${login_node}"
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=testing K3S_URL=https://${login_node}:6443 K3S_TOKEN=${secret_token} sh -
```

However, that won't fly in an environment without root.

We are close!

#### Back to Login...

Back on the login node, you should be able to see your nodes:

```bash
gcloud compute ssh gffw-login-001 --zone us-central1-a
```

Try to deploy something.

```bash
wget https://raw.githubusercontent.com/flux-framework/flux-operator/main/examples/nested/k3s/basic/my-echo.yaml
```
```bash
$ kubectl apply -f my-echo.yaml 
service/my-echo created
deployment.apps/my-echo created
```
```bash
$ kubectl get deployment
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
my-echo   1/1     1            1           26s
```

And that's it! When you are done:

```bash
$ make destroy
```
