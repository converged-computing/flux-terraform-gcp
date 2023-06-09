# Basic Flux Framework on GCP

This deployment illustrates deploying a flux-framework cluster on GCP.

# Usage

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images)
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
Verify that the cluster is up:

```bash
gcloud compute ssh gffw-login-001 --zone us-central1-a
```

And then you should be able to interact with Flux!

```bash
$ flux resource list
     STATE PROPERTIES NNODES   NCORES NODELIST
      free x86-64,e2       1        2 gffw-login-001
      free x86-64,c2       2       16 gffw-compute-a-[001-002]
 allocated                 0        0 
      down                 0        0 
```
```bash
$ flux run -N 2 hostname
gffw-compute-a-001
gffw-compute-a-002
```

And when you are done:

```bash
$ make destroy
```

## Advanced

### Adding Buckets

You'll first want to make your buckets! Edit the script [mkbuckets.sh](mkbuckets.sh)
to your needs. E.g.,:

 - If the bucket already exists, comment out the creation command for it

You'll want to run the script and provide the name of your main bucket (e.g.,
the one with some data to mount):

```bash
$ ./mkbuckets.sh flux-operator-bucket
```

And then add the logic from [fuse-mounts.sh](fuse-mounts.sh) to your boot script.
 
