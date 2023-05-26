# Basic Flux Framework on GCP

This deployment illustrates deploying a flux-framework cluster on GCP.
All components are included here.

# Usage

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images)
Initialize the deployment with the command:

```bash
$ terraform init
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

Note that the above working has some (not merged yet) fixed for the upstream recipe.
Stay tuned! When you are finished destroy the cluster:

```bash
terraform destroy -var-file basic.tfvars \
  -var region=us-central1 \
  -var project_id=$(gcloud config get-value core/project) \
  -var network_name=foundation-net \
  -var zone=us-central1-a
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
 
