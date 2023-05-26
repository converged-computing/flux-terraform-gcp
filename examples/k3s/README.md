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
Before you shell in, copy the flux job (to launch and install k3s)

```bash
$ gcloud compute scp --zone us-central1-a ./scripts/flux_job.sh gffw-login-001:/tmp/flux_job.sh
```

After it's done creating and you've copied the file, shell in to verify that the cluster is up:

```bash
$ gcloud compute ssh gffw-login-001 --zone us-central1-a
```

Is it up?

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

Yes! Next we want to run our job that will install k3s and run the agent / service.
Note that you very likely could install first and then just start with a new token -
you'll want to do this for a production setup - there are many ways to start Flux,
and the way I chose here intends to setup the control plane and nodes,
and then give you an interactive session.

```bash
$ flux alloc -N 3 /bin/bash /tmp/flux_job.sh
```

For debugging, if you shell into a worker node (and you are outside the allocation
running) you should be able to see it:

```bash
$ flux jobs -a
       JOBID USER     NAME       ST NTASKS NNODES     TIME INFO
   ƒQ6MxnsnF vsochat_ flux        R      3      3   18.43s gffw-login-001,gffw-compute-a-[001-002]
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

Note that the worker steps are a little slow (I've run them manually and they take
on the order of minutes) so likely you will want to be patient. When you first enter
the interactive shell, you'll likely only see the control plane. But eventually
(and hopefully!) you see the nodes:

```bash
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE   VERSION
gffw-compute-a-001   Ready    <none>                 14m   v1.26.4+k3s1
gffw-login-001       Ready    control-plane,master   40m   v1.26.4+k3s1
```

I suspect if we grab the install script and then can see what is taking a long time, these
steps (primarily installs of stuffs) can be run apriori. I also wish there was a better
way to get the logs for each of the startup tasks (e.g., for the two compute nodes)
because it's very hard to debug. If you need to shell in to a worker to start it manually:

```bash
export secret_token=pancakes-chicken-finger-change-me

# Note the login node hostname is hard coded here!!
login_node=$(nslookup gffw-login-001 | grep Address |  sed -n '2 p' |  sed 's/Address: //g')
echo "Login node is ${login_node}"
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=testing K3S_URL=https://${login_node}:6443 K3S_TOKEN=${secret_token} sh -
```

I had to do this manually on the worker nodes, and I think it's because my strategy for issuing the commands
is not right. I think likely we want to do some kind of flux broker or flux start or flux batch.
Too tired to try tonight. When they are all registered:

```bash
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE   VERSION
gffw-compute-a-001   Ready    <none>                 17m   v1.26.4+k3s1
gffw-login-001       Ready    control-plane,master   42m   v1.26.4+k3s1
gffw-compute-a-002   Ready    <none>                 1s    v1.27.2-rc3+k3s1
```

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
