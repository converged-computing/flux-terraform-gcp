# Flux with Usernetes on GCP

This deployment illustrates deploying a flux-framework cluster on GCP
with Usernetes installed on "bare metal." All components are included here.

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

Login to the login node!

```bash
$ gcloud compute ssh gffw-login-001 --zone us-central1-a
```

STOPPED HERE - we need to have these gid/uids be correct, otherwise I need to manually change
them on all nodes. Note that since we cannot disable OSlogin, we need to change our user name in the gid/uid maps.


```bash
sudo vim /etc/subuid
sudo vim /etc/subgid
```
```diff
-olduid:165536:65536
+newuid:165536:65536
```

If you want to see startup logs:

```bash
sudo journalctl -u google-startup-scripts.service
```
Or run again:

```bash
sudo google_metadata_script_runner startup
```

TODO when we have the above fixed...
And that's it! When you are done:

```bash
$ make destroy
```
