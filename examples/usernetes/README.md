# Flux Framework + Usernetes on GCP

This deployment illustrates deploying a flux-framework cluster on GCP
with usernetes installed. We use one single image base and configure via a bootscript.
I am trying to follow the logic in [this example in docker-compose](https://github.com/rootless-containers/usernetes/blob/master/docker-compose.yml).

# Usage

## Build images

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images/bursted)
First, edit variables in [basic.tfvars](basic.tfvars). 

## Curve Cert

We will need a shared curve certificate for the nodes. We provide an example [curve.cert](curve.cert),
however you can (and should) generate one on your own for cases that go beyond testing. You can do this
with a flux container:

```bash
docker run -it fluxrm/flux-sched:focal bash
flux keygen curve.cert
```

Then copy the file locally, and later we are going to encode it into our boot script.

## Bootscript Template

> Note that we have a template provided if you don't want to customize defaults.

Set variables for your nodelist and curve certificate (and check they are good):
Make the generated script with your NODEDLIST:

```bash
make template NODELIST='gffw-compute-a-[001-003]'
```

Then base64 encode your curve cert and copy paste it into the variable `CURVECERT`.
Note that this can work in a programming language but bash does weird things with
the unexpected characters.

```
curve=$(cat curve.cert | base64)
$ echo $curve
```

Finally (sorry I know this is annoying) copy the entire bootscript into the
variable in [basic.tfvars](basic.tfvars).

## Deploy

Initialize the deployment with the command:

```bash
$ terraform init
```

I find it's easiest to export my Google project in the environment for any terraform configs
that mysteriously need it.

```bash
export GOOGLE_PROJECT=$(gcloud config get-value core/project)
```

You'll want to inspect basic.tfvars and change for your use case (or keep as is for a small debugging cluster). Then:

```bash
$ make
```

And inspect the [Makefile](Makefile) to see the terraform commands we apply
to init, format, validate, and deploy. The deploy will setup networking and all the instances! Note that
you can change any of the `-var` values to be appropriate for your environment.
Verify that the cluster is up. You can shell into any compute node.

<details>

<summary>Extra Debugging Details</summary>

```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a
```

You can check the startup scripts to make sure that everything finished.

```bash
sudo journalctl -u google-startup-scripts.service
```

Note that I logged into all three nodes to ensure the home was created (I do it backwards so I finish up on 001):

</details>

I would give a few minutes for the boot script to run. next we are going to init the NFS mount
by running ssh as our user, and changing variables in `/etc/sub(u|g)id`

```bash
for i in 1 2 3; do
  instance=gffw-compute-a-00${i}
  login_user=$(gcloud compute ssh $instance --zone us-central1-a -- whoami)
done
echo "Found login user ${login_user}"
```

Next change the uid/gid this might vary for you - change the usernames based on the users you have)

```bash
for i in 1 2 3; do
  instance=gffw-compute-a-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subuid
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subgid
done
```

One sanity check:

```bash
$ gcloud compute ssh $instance --zone us-central1-a -- cat /etc/subgid
$ gcloud compute ssh $instance --zone us-central1-a -- cat /etc/subuid
```

<details> 

<summary> Example interaction with Flux </summary>

I'm hoping that's an issue we only see here. And then you should be able to interact with Flux!

```bash
$ gcloud compute ssh $instance --zone us-central1-a -- flux resource list
```
```console
$ flux resource list
     STATE NNODES   NCORES NODELIST
      free      3       12 gffw-compute-a-[001-003]
 allocated      0        0 
      down      0        0 
```

Here is an example of how to run a hostname job (I ran this ssh'd in)
```bash
$ flux run --cwd /tmp -N 2 hostname
gffw-compute-a-001
gffw-compute-a-002
```

</details>

For the rest of this experiment we will work to setup each node. We will do this for one node, and it should
persist to the others. Note that we are using a custom build from researchapps with a few bug fixes/extra
verbosity. We will copy all scripts first. Change the below for your username

```bash
$ gcloud compute ssh gffw-compute-a-001 --zone us-central1-a -- mkdir -p /home/sochat1_llnl_gov/scripts
$ gcloud compute scp ./scripts --recurse gffw-compute-a-001:/home/sochat1_llnl_gov --zone=us-central1-a
```

This should now install usernetes (get the .tbz and extract). The filesystem is shared so we do this once.

```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a -- bash ./scripts/install_usernetes.sh
```

Now ensure we have cgroups2 enabled for each node:

```bash
for i in 1 2 3; do
  gcloud compute ssh gffw-compute-a-00${i} --zone us-central1-a -- bash ./scripts/delegate.sh
done
```

At the end of each you should see:

```console
cpuset cpu io memory pids
```

Update the install.sh (there is a quoting bug)

```bash
$ gcloud compute scp ./scripts/install.sh gffw-compute-a-001:/home/sochat1_llnl_gov/usernetes/install.sh --zone=us-central1-a
```

Now try running the install script for each. I did this in separate terminals so I could watch all of them.

```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a -- bash ./scripts/001-control-plane.sh
gcloud compute ssh gffw-compute-a-002 --zone us-central1-a -- bash ./scripts/002-crio.sh
gcloud compute ssh gffw-compute-a-003 --zone us-central1-a -- bash ./scripts/003-containerd.sh
```

The corresponding logic for the above is in [scripts/batch.sh](scripts/batch.sh). We would eventually want to start this with flux.

### Manual Testing

Note that a few times I'd extract usernetes, and then try to cd to ~/usernetes and it would tell me it wasn't there (and my entire home was gone). I think this is some issue with NFS. In these cases I tried again. Don't forget to fix the bug in install.sh noted in the section below, and then submit the install as a flux job.

```bash
flux submit -N 3 --watch ./batch.sh
```

In practice this didn't work, and I saw errors about services:

```
[WARNING] cpu controller might not be enabled, you need to configure /etc/systemd/system/user@.service.d , see https://rootlesscontaine.rs/getting-started/common/cgroup2/
[WARNING] Kernel module x_tables not loaded
[WARNING] Kernel module xt_MASQUERADE not loaded
[WARNING] Kernel module xt_tcpudp not loaded
```
So I've been testing the manual approach, below.

## Node gffw-compute-a-001

I found to get this working I needed to login to the 001 node, run the steps at the top of [scripts/batch.sh](scripts/batch.sh)
to download usernetes in HOME, and then before running anything, update the generation of the env file in `$HOME/usersnetes/install.sh`

```diff
- U7S_ROOTLESSKIT_PORTS=${publish}
+ U7S_ROOTLESSKIT_PORTS="${publish}"
```

And then run the install.sh command from [scripts/batch.sh](scripts/batch.sh). Remember that we have an NFS
filesystem so you only need to clone and generate certs once (the other nodes see the same HOME).
And that generates to `/home/sochat1_llnl_gov/.config/usernetes/env`. While [debugging](#debugging), I 
I wound up doing all the changes you see for the first 001 node in [scripts/batch.sh](scripts/batch.sh)
but then when everything is running it should look like this:

```console
[sochat1_llnl_gov@gffw-compute-a-001 ~]$ cd usernetes
[sochat1_llnl_gov@gffw-compute-a-001 usernetes]$     /bin/bash ./install.sh --wait-init-certs --start=u7s-master-with-etcd.target --cidr=10.0.100.0/24 --publish=0.0.0.0:2379:2379/tcp --publish=0.0.0.0:6443:6443/tcp --cni=flannel --cri=crio
[INFO] Rootless cgroup (v2) is supported
[WARNING] Kernel module x_tables not loaded
[WARNING] Kernel module xt_MASQUERADE not loaded
[WARNING] Kernel module xt_tcpudp not loaded
[INFO] Waiting for certs to be created.:
OK
[INFO] Base dir: /home/sochat1_llnl_gov/usernetes
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-master-with-etcd.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-rootlesskit.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-etcd.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-etcd.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-master.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-apiserver.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-controller-manager.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-scheduler.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-node.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kubelet-crio.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-proxy.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-flanneld.service
[INFO] Starting u7s-master-with-etcd.target
+ systemctl --user -T enable u7s-master-with-etcd.target
+ systemctl --user -T start u7s-master-with-etcd.target
Enqueued anchor job 307 u7s-master-with-etcd.target/start.

real    0m0.005s
user    0m0.001s
sys     0m0.003s
+ systemctl --user --all --no-pager list-units 'u7s-*'
UNIT                                LOAD   ACTIVE SUB     DESCRIPTION                                                       
u7s-etcd.service                    loaded active running Usernetes etcd service                                            
u7s-flanneld.service                loaded active running Usernetes flanneld service                                        
u7s-kube-apiserver.service          loaded active running Usernetes kube-apiserver service                                  
u7s-kube-controller-manager.service loaded active running Usernetes kube-controller-manager service                         
u7s-kube-proxy.service              loaded active running Usernetes kube-proxy service                                      
u7s-kube-scheduler.service          loaded active running Usernetes kube-scheduler service                                  
u7s-kubelet-crio.service            loaded active running Usernetes kubelet service (crio)                                  
u7s-rootlesskit.service             loaded active running Usernetes RootlessKit service (crio)                              
u7s-etcd.target                     loaded active active  Usernetes target for etcd                                         
u7s-master-with-etcd.target         loaded active active  Usernetes target for Kubernetes master components (including etcd)
u7s-master.target                   loaded active active  Usernetes target for Kubernetes master components                 
u7s-node.target                     loaded active active  Usernetes target for Kubernetes node components (crio)            

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
SUB    = The low-level unit activation state, values depend on unit type.

12 loaded units listed.
To show all installed unit files use 'systemctl list-unit-files'.
+ set +x
[INFO] Installing CoreDNS
+ sleep 3
+ kubectl get nodes -o wide
NAME                 STATUS   ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                           KERNEL-VERSION                       CONTAINER-RUNTIME
gffw-compute-a-001   Ready    <none>   13m   v1.27.2   10.0.100.100   <none>        Rocky Linux 8.8 (Green Obsidian)   4.18.0-477.15.1.el8_8.cloud.x86_64   cri-o://1.27.0
+ kubectl apply -f /home/sochat1_llnl_gov/usernetes/manifests/coredns.yaml
serviceaccount/coredns unchanged
clusterrole.rbac.authorization.k8s.io/system:coredns unchanged
clusterrolebinding.rbac.authorization.k8s.io/system:coredns unchanged
configmap/coredns unchanged
deployment.apps/coredns unchanged
service/kube-dns unchanged
+ set +x
[INFO] Waiting for CoreDNS pods to be available
+ sleep 3
+ kubectl -n kube-system wait --for=condition=ready pod -l k8s-app=kube-dns
pod/coredns-8557665db-5rxkp condition met
pod/coredns-8557665db-fnnjj condition met
+ kubectl get pods -A -o wide
NAMESPACE     NAME                      READY   STATUS    RESTARTS   AGE   IP          NODE                 NOMINATED NODE   READINESS GATES
kube-system   coredns-8557665db-5rxkp   1/1     Running   0          49m   10.5.15.3   gffw-compute-a-001   <none>           <none>
kube-system   coredns-8557665db-fnnjj   1/1     Running   0          49m   10.5.15.2   gffw-compute-a-001   <none>           <none>
+ set +x
[INFO] Installation complete.
[INFO] Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.
[INFO] Hint: export KUBECONFIG=/home/sochat1_llnl_gov/.config/usernetes/master/admin-localhost.kubeconfig
```

Then I did the last step (and added to my bash profile):

```console
echo "export KUBECONFIG=/home/sochat1_llnl_gov/.config/usernetes/master/admin-localhost.kubeconfig" >> ~/.bashrc
echo "export PATH=~/usernetes/bin:$PATH" >> ~/.bashrc
export KUBECONFIG=/home/sochat1_llnl_gov/.config/usernetes/master/admin-localhost.kubeconfig
```

And you can get the control plane node now:

```bash
$ kubectl get nodes
```
```console
$ kubectl get nodes
NAME                 STATUS   ROLES    AGE   VERSION
gffw-compute-a-001   Ready    <none>   17m   v1.27.2
```

## Node gffw-compute-a-002

Remember we have NFS, so the files / changes to bashrc are going to be present here! So we can run
the install.sh step for 002 (see again batch.sh for this node (this is the crio node)):

```bash
$ /bin/bash ./install.sh --wait-init-certs --start=u7s-node.target --cidr=10.0.101.0/24 --publish=0.0.0.0:10250:10250/tcp --publish=0.0.0.0:8472:8472/udp --cni=flannel --cri=crio
```
```console
[INFO] Rootless cgroup (v2) is supported
[WARNING] Kernel module x_tables not loaded
[WARNING] Kernel module xt_MASQUERADE not loaded
[WARNING] Kernel module xt_tcpudp not loaded
[INFO] Waiting for certs to be created.:
OK
[INFO] Base dir: /home/sochat1_llnl_gov/usernetes
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-master-with-etcd.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-rootlesskit.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-etcd.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-etcd.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-master.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-apiserver.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-controller-manager.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-scheduler.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-node.target
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kubelet-crio.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-proxy.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-flanneld.service
[INFO] Starting u7s-node.target
+ systemctl --user -T enable u7s-node.target
Created symlink /home/sochat1_llnl_gov/.config/systemd/user/u7s.target.wants/u7s-node.target → /home/sochat1_llnl_gov/.config/systemd/user/u7s-node.target.
+ systemctl --user -T start u7s-node.target
Enqueued anchor job 10 u7s-node.target/start.
Enqueued auxiliary job 21 u7s-rootlesskit.service/start.
Enqueued auxiliary job 11 u7s-kube-proxy.service/start.
Enqueued auxiliary job 22 u7s-flanneld.service/start.
Enqueued auxiliary job 13 u7s-kubelet-crio.service/start.

real    0m1.589s
user    0m0.003s
sys     0m0.002s
+ systemctl --user --all --no-pager list-units 'u7s-*'
UNIT                                LOAD   ACTIVE   SUB     DESCRIPTION                                                       
u7s-etcd.service                    loaded inactive dead    Usernetes etcd service                                            
u7s-flanneld.service                loaded active   running Usernetes flanneld service                                        
u7s-kube-apiserver.service          loaded inactive dead    Usernetes kube-apiserver service                                  
u7s-kube-controller-manager.service loaded inactive dead    Usernetes kube-controller-manager service                         
u7s-kube-proxy.service              loaded active   running Usernetes kube-proxy service                                      
u7s-kube-scheduler.service          loaded inactive dead    Usernetes kube-scheduler service                                  
u7s-kubelet-crio.service            loaded active   running Usernetes kubelet service (crio)                                  
u7s-rootlesskit.service             loaded active   running Usernetes RootlessKit service (crio)                              
u7s-etcd.target                     loaded inactive dead    Usernetes target for etcd                                         
u7s-master-with-etcd.target         loaded inactive dead    Usernetes target for Kubernetes master components (including etcd)
u7s-master.target                   loaded inactive dead    Usernetes target for Kubernetes master components                 
u7s-node.target                     loaded active   active  Usernetes target for Kubernetes node components (crio)            

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
SUB    = The low-level unit activation state, values depend on unit type.

12 loaded units listed.
To show all installed unit files use 'systemctl list-unit-files'.
+ set +x
[INFO] Installation complete.
[INFO] Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.
```

I also ran the last suggested command.

## Node gffw-compute-a-003

Finally the last node, same deal.

## Cleanup

When you are done, exit and:

```bash
$ make destroy
```

## Next Steps

We need to better understand this multi-node setup, and how the components are supposed to be working together
(and why they are not). The first bug to address is the fact that we are expecting docker-compose binds, and instead
of copying an actual node directory to ./node we should be able to specify it somewhere.

## Advanced

### Debugging

If you get an error on starting usernetes, likely your gid/uid doesn't correspond
with the user account you logged in with. Try running this:

```bash
source $HOME/.config/usernetes/env
$HOME/usernetes/boot/rootlesskit.sh $HOME/usernetes/boot/containerd.sh
```
And if you see this:

```console
[rootlesskit:parent] error: failed to setup UID/GID map: failed to compute uid/gid map: No subuid ranges found for user 2121336887
```

Try `gcloud auth login` with your correct id first. It needs to have a range in:

```console
cat /etc/subuid
cat /etc/subgid
```

And you can use this same strategy to debug - look for the service files in
`$HOME/.config/systemd/user/` and then source the environment and manually run
the `ExecStart` to see the actual error. As an example, when I was debugging it 
helped to check individual services (that should be running):

```bash
$ systemctl --user --all --no-pager list-units 'u7s-*'
```

And then, for example, to see the filepath for a specific service:

```bash
systemctl --user status 'u7s-flanneld.service'
cat /home/sochat1_llnl_gov/.config/systemd/user/u7s-flanneld.service
```
