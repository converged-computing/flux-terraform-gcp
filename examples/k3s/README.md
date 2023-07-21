# Flux Framework + K3s on GCP

This deployment illustrates deploying a flux-framework cluster on GCP
with k3s (root needed) installed. We use one single image base and configure via a bootscript.

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
make template NODELIST='gffw-compute-a-[001-003]' LEADER='gffw-compute-a-001' SECRETTOKEN='k3s_secret_token'
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

You'll want to inspect basic.tfvars and change for your use case. Then:

```bash
$ make
```

And inspect the [Makefile](Makefile) to see the terraform commands we apply
to init, format, validate, and deploy. The deploy will setup networking and all the instances! Note that
you can change any of the `-var` values to be appropriate for your environment.
Verify that the cluster is up. You can shell into any compute node.

```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a
```

You can check the startup scripts to make sure that everything finished.

```bash
sudo journalctl -u google-startup-scripts.service
```

When you login, you should be able to interact with Flux!

```bash
$ flux resource list
     STATE NNODES   NCORES NODELIST
      free      3       12 gffw-compute-a-[001-003]
 allocated      0        0 
      down      0        0 
```
```bash
$ flux run --cwd /tmp -N 2 hostname
gffw-compute-a-001
gffw-compute-a-002
```

Note that current bugs I'm running into:

 - the nfs doesn't always work - e.g., I sometimes don't see the files shared across nodes, and manually do it:

This creates the home directories:
 
```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a
gcloud compute ssh gffw-compute-a-002 --zone us-central1-a
gcloud compute ssh gffw-compute-a-003 --zone us-central1-a
```

And below you can see doing the scp to separate nodes if you need!

## Batch Testing

Back on your host, copy the batch scripts over:

```bash
$ gcloud compute scp ./scripts/k3s/*  sochat1_llnl_gov@gffw-compute-a-001:/home/sochat1_llnl_gov/
$ gcloud compute scp ./scripts/k3s/*  sochat1_llnl_gov@gffw-compute-a-002:/home/sochat1_llnl_gov/
$ gcloud compute scp ./scripts/k3s/*  sochat1_llnl_gov@gffw-compute-a-003:/home/sochat1_llnl_gov/
```

Shell in:

```bash
gcloud compute ssh gffw-compute-a-001 --zone us-central1-a
```

Run a batch job that will hit three workers.

```bash
$ flux batch -N 3 --error k3s_installation.out --output k3s_installation.out flux_batch_job.sh "k3s_secret_token"
```

You can look at the script logs/ runtime logs like this if you need to debug.

```bash
$ cat $HOME/<script_name>.out
```

For example, here is a working run in `k3s_starter.out`

<details>

<summary>k3s-starter.out</summary>

```console
I'm a worker, gffw-compute-a-003
I'm a worker, gffw-compute-a-002
I'm the leader, gffw-compute-a-001
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}The K3S service is UP!
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}The K3S service is UP!
K3S_TOKEN=k3s_secret_token
K3S_URL=https://gffw-compute-a-001:6443
K3S_URL=https://gffw-compute-a-001:6443
K3S_TOKEN=k3s_secret_token
K3S_TOKEN=k3s_secret_token
● k3s.service - Lightweight Kubernetes
   Loaded: loaded (/etc/systemd/system/k3s.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-21 23:29:01 UTC; 12min ago
     Docs: https://k3s.io
 Main PID: 9273 (k3s-server)
    Tasks: 150
   Memory: 1.3G
   CGroup: /system.slice/k3s.service
           ├─ 9273 /usr/bin/k3s server
           ├─ 9349 containerd 
           ├─10226 /var/lib/rancher/k3s/data/163665c44bcc8e97514aeb518069c3c55e5ad6226d4ebf3c6d89cbd4057b6809/bin/containerd-shim-runc-v2 -namespace k8s.io -id 199b467d652f260d0fd1932dcf8f0ccd3f277a0ac1aa1343153661904664f9f4 -address /run/k3s/containerd/containerd.sock
           ├─10310 /var/lib/rancher/k3s/data/163665c44bcc8e97514aeb518069c3c55e5ad6226d4ebf3c6d89cbd4057b6809/bin/containerd-shim-runc-v2 -namespace k8s.io -id da5eaf2036372743f16f05224f58b4d1e9652372622406404ed789aa64d25c8a -address /run/k3s/containerd/containerd.sock
           ├─10347 /var/lib/rancher/k3s/data/163665c44bcc8e97514aeb518069c3c55e5ad6226d4ebf3c6d89cbd4057b6809/bin/containerd-shim-runc-v2 -namespace k8s.io -id e73548c3de6b18ecd629e5a12e76c81e825014265185c955fadd74a216862f22 -address /run/k3s/containerd/containerd.sock
           ├─11487 /var/lib/rancher/k3s/data/163665c44bcc8e97514aeb518069c3c55e5ad6226d4ebf3c6d89cbd4057b6809/bin/containerd-shim-runc-v2 -namespace k8s.io -id e5e0721f689b03e3efa4a12e96f9c1802fcda9d17580d55a9e01c15191768619 -address /run/k3s/containerd/containerd.sock
           └─11585 /var/lib/rancher/k3s/data/163665c44bcc8e97514aeb518069c3c55e5ad6226d4ebf3c6d89cbd4057b6809/bin/containerd-shim-runc-v2 -namespace k8s.io -id 34b9e8d763276fdeeff07eb4c559f195826176414c88770429501a36352e99a3 -address /run/k3s/containerd/containerd.sock

Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.074251    9273 resource_quota_monitor.go:218] QuotaMonitor created object count evaluator for tlsstores.traefik.containo.us
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.074271    9273 resource_quota_monitor.go:218] QuotaMonitor created object count evaluator for traefikservices.traefik.containo.us
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.074285    9273 resource_quota_monitor.go:218] QuotaMonitor created object count evaluator for ingressroutetcps.traefik.containo.us
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.074300    9273 resource_quota_monitor.go:218] QuotaMonitor created object count evaluator for ingressroutes.traefik.containo.us
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.074358    9273 shared_informer.go:270] Waiting for caches to sync for resource quota
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.175371    9273 shared_informer.go:277] Caches are synced for resource quota
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.494540    9273 shared_informer.go:270] Waiting for caches to sync for garbage collector
Jul 21 23:29:46 gffw-compute-a-001 k3s[9273]: I0721 23:29:46.494588    9273 shared_informer.go:277] Caches are synced for garbage collector
Jul 21 23:33:57 gffw-compute-a-001 k3s[9273]: time="2023-07-21T23:33:57Z" level=info msg="COMPACT revision 0 has already been compacted"
Jul 21 23:38:57 gffw-compute-a-001 k3s[9273]: time="2023-07-21T23:38:57Z" level=info msg="COMPACT revision 0 has already been compacted"
● k3s-agent.service - Lightweight Kubernetes
   Loaded: loaded (/etc/systemd/system/k3s-agent.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-21 23:41:18 UTC; 255ms ago
     Docs: https://k3s.io
  Process: 8532 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
  Process: 8531 ExecStartPre=/sbin/modprobe br_netfilter (code=exited, status=0/SUCCESS)
  Process: 8529 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
 Main PID: 8533 (k3s-agent)
    Tasks: 31
   Memory: 228.9M
   CGroup: /system.slice/k3s-agent.service
           ├─8533 /usr/bin/k3s agent
           └─8556 containerd 

Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.471753    8533 status_manager.go:176] "Starting to sync pod status with apiserver"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.471773    8533 kubelet.go:2113] "Starting kubelet main sync loop"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: E0721 23:41:18.471817    8533 kubelet.go:2137] "Skipping pod synchronization" err="PLEG is not healthy: pleg has yet to be successful"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.472513    8533 kuberuntime_manager.go:1114] "Updating runtime config through cri with podcidr" CIDR="10.42.2.0/24"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.472844    8533 kubelet_network.go:61] "Updating Pod CIDR" originalPodCIDR="" newPodCIDR="10.42.2.0/24"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: time="2023-07-21T23:41:18Z" level=info msg="Starting the netpol controller version , built on , go1.19.9"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: time="2023-07-21T23:41:18Z" level=info msg="k3s agent is up and running"
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.488206    8533 network_policy_controller.go:163] Starting network policy controller
Jul 21 23:41:18 gffw-compute-a-002 systemd[1]: Started Lightweight Kubernetes.
Jul 21 23:41:18 gffw-compute-a-002 k3s[8533]: I0721 23:41:18.526276    8533 network_policy_controller.go:175] Starting network policy controller full sync goroutine
● k3s-agent.service - Lightweight Kubernetes
   Loaded: loaded (/etc/systemd/system/k3s-agent.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-21 23:41:18 UTC; 364ms ago
     Docs: https://k3s.io
  Process: 8643 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
  Process: 8642 ExecStartPre=/sbin/modprobe br_netfilter (code=exited, status=0/SUCCESS)
  Process: 8640 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
 Main PID: 8644 (k3s-agent)
    Tasks: 32
   Memory: 230.1M
   CGroup: /system.slice/k3s-agent.service
           ├─8644 /usr/bin/k3s agent
           └─8667 containerd 

Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.438810    8644 kubelet_network.go:61] "Updating Pod CIDR" originalPodCIDR="" newPodCIDR="10.42.1.0/24"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.446927    8644 kubelet_network_linux.go:63] "Initialized iptables rules." protocol=IPv6
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.446944    8644 status_manager.go:176] "Starting to sync pod status with apiserver"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.446960    8644 kubelet.go:2113] "Starting kubelet main sync loop"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: E0721 23:41:18.446994    8644 kubelet.go:2137] "Skipping pod synchronization" err="PLEG is not healthy: pleg has yet to be successful"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: time="2023-07-21T23:41:18Z" level=info msg="Starting the netpol controller version , built on , go1.19.9"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: time="2023-07-21T23:41:18Z" level=info msg="k3s agent is up and running"
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.453679    8644 network_policy_controller.go:163] Starting network policy controller
Jul 21 23:41:18 gffw-compute-a-003 systemd[1]: Started Lightweight Kubernetes.
Jul 21 23:41:18 gffw-compute-a-003 k3s[8644]: I0721 23:41:18.549870    8644 network_policy_controller.go:175] Starting network policy controller full sync goroutine
NAME                 STATUS   ROLES                  AGE   VERSION
gffw-compute-a-001   Ready    control-plane,master   12m   v1.26.5+k3s1
gffw-compute-a-003   Ready    <none>                 25s   v1.26.5+k3s1
gffw-compute-a-002   Ready    <none>                 25s   v1.26.5+k3s1
No resources found in default namespace.
namespace/yelb created
service/redis-server created
service/yelb-db created
service/yelb-appserver created
service/yelb-ui created
deployment.apps/yelb-ui created
deployment.apps/redis-server created
deployment.apps/yelb-db created
deployment.apps/yelb-appserver created
NAME                              READY   STATUS              RESTARTS   AGE   IP       NODE                 NOMINATED NODE   READINESS GATES
yelb-ui-79bb656bc6-zjm54          0/1     ContainerCreating   0          0s    <none>   gffw-compute-a-002   <none>           <none>
redis-server-76d7b647dd-hkt2g     0/1     ContainerCreating   0          0s    <none>   gffw-compute-a-003   <none>           <none>
yelb-db-5dfdd5d44f-8l6kl          0/1     ContainerCreating   0          0s    <none>   gffw-compute-a-003   <none>           <none>
yelb-appserver-56d6d6685b-khvbg   0/1     ContainerCreating   0          0s    <none>   gffw-compute-a-002   <none>           <none>
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
redis-server     ClusterIP   10.43.193.225   <none>        6379/TCP       1s
yelb-db          ClusterIP   10.43.173.144   <none>        5432/TCP       1s
yelb-appserver   ClusterIP   10.43.18.113    <none>        4567/TCP       1s
yelb-ui          NodePort    10.43.76.75     <none>        80:30001/TCP   1s
```

</details>
That's it. Enjoy! We hopefully will be able to continue developing this (with rootless)
when we better understand the underlying issues with usernetes (and can translate them over here).
