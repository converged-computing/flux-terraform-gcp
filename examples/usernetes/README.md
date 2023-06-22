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

You can then deploy with make:

```bash
$ make
```

Since we need to have enable_os_login set to true for this to work, we also need to manually
change the uid/gid settings to our actual user (not the one from our operating system).
You'll need to do this for each instance. This won't work in a production setting with a ton
of nodes, but should work here. For each of:

```bash
$ gcloud compute ssh gffw-login-001 --zone us-central1-a
$ gcloud compute ssh gffw-manager-001 --zone us-central1-a
$ gcloud compute ssh gffw-compute-a-001 --zone us-central1-a
$ gcloud compute ssh gffw-compute-a-002 --zone us-central1-a
```

Update these files:

```bash
sudo vim /etc/subuid
sudo vim /etc/subgid
```
```diff
-olduid:165536:65536
+newuid:165536:65536
```

It should be the `$USER` variable on your instance (and not your local operating system id!)

Then login again to the login node!

```bash
$ gcloud compute ssh gffw-login-001 --zone us-central1-a
```

If you want to see startup logs:

```bash
sudo journalctl -u google-startup-scripts.service
```
I noticed that (even with a bootscript) I didn't see any startup scripts. This might be a bug we need to look into.
If there is a detected startup script, you can run again as follows:

```bash
sudo google_metadata_script_runner startup
```

Since we didn't have our startup script run, we can instead do this manually.
Follow the logic in [scripts/boot_script.sh](scripts/boot_script.sh) to do
installs on each specific node. And actually, the main and crio nodes need to
be started at the same time - I used several terminals to run them at the same time.
This is a difficulty in the manual startup, and likely even the automated one
would have a hard time getting it right!

I'm currently hitting this error:

```bash
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
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-containerd-fuse-overlayfs-grpc.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kubelet-containerd.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-kube-proxy.service
[INFO] Installing /home/sochat1_llnl_gov/.config/systemd/user/u7s-flanneld.service
[INFO] Starting u7s-node.target
+ systemctl --user -T enable u7s-node.target
+ systemctl --user -T start u7s-node.target
Enqueued anchor job 133 u7s-node.target/start.
Enqueued auxiliary job 145 u7s-kubelet-containerd.service/start.
Enqueued auxiliary job 134 u7s-containerd-fuse-overlayfs-grpc.service/start.
Enqueued auxiliary job 144 u7s-kube-proxy.service/start.
A dependency job for u7s-node.target failed. See 'journalctl -xe' for details.
```

And it's retrying a lot:

```
Jun 22 20:29:07 gffw-compute-a-002 systemd[5463]: u7s-containerd-fuse-overlayfs-grpc.service: Start request repeated too quic>
Jun 22 20:29:07 gffw-compute-a-002 systemd[5463]: u7s-containerd-fuse-overlayfs-grpc.service: Failed with result 'exit-code'.
-- Subject: Unit failed
-- Defined-By: systemd
-- Support: https://lists.freedesktop.org/mailman/listinfo/systemd-devel
-- 
-- The unit UNIT has entered the 'failed' state with result 'exit-code'.
Jun 22 20:29:07 gffw-compute-a-002 systemd[5463]: Failed to start Usernetes containerd-fuse-overlayfs-grpc service.
-- Subject: Unit UNIT has failed
-- Defined-By: systemd
-- Support: https://lists.freedesktop.org/mailman/listinfo/systemd-devel
-- 
-- Unit UNIT has failed.
-- 
-- The result is failed.
Jun 22 20:29:27 gffw-compute-a-002 systemd[1]: Starting Cleanup of Temporary Directories...
-- Subject: Unit systemd-tmpfiles-clean.service has begun start-up
-- Defined-By: systemd
-- Support: https://lists.freedesktop.org/mailman/listinfo/systemd-devel
-- 
-- Unit systemd-tmpfiles-clean.service has begun starting up.
Jun 22 20:29:27 gffw-compute-a-002 sudo[7575]: sochat1_llnl_gov : TTY=pts/0 ; PWD=/home/sochat1_llnl_gov/usernetes ; USER=roo>
Jun 22 20:29:27 gffw-compute-a-002 sudo[7575]: pam_unix(sudo:session): session opened for user root by sochat1_llnl_gov(uid=0)
```

We can dig a little deeper:

```bash
$ systemctl --user status u7s-containerd-fuse-overlayfs-grpc.service
● u7s-containerd-fuse-overlayfs-grpc.service - Usernetes containerd-fuse-overlayfs-grpc service
   Loaded: loaded (/home/sochat1_llnl_gov/.config/systemd/user/u7s-containerd-fuse-overlayfs-grpc.service; static; vendor pre>
   Active: failed (Result: exit-code) since Thu 2023-06-22 20:34:18 UTC; 8s ago
  Process: 8017 ExecStart=/home/sochat1_llnl_gov/usernetes/boot/containerd-fuse-overlayfs-grpc.sh (code=exited, status=1/FAIL>
 Main PID: 8017 (code=exited, status=1/FAILURE)
lines 1-5/5 (END)
```

And look at the script `/home/sochat1_llnl_gov/usernetes/boot/containerd-fuse-overlayfs-grpc.sh`

```bash
#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

mkdir -p $XDG_RUNTIME_DIR/usernetes/containerd $XDG_DATA_HOME/usernetes/containerd

exec containerd-fuse-overlayfs-grpc \
	$@ \
	$XDG_RUNTIME_DIR/usernetes/containerd/fuse-overlayfs.sock \
	$XDG_DATA_HOME/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs
```

AHH we found the error!

```
INFO[0000] containerd-fuse-overlayfs-grpc Version="v1.0.6" Revision="a705ae6f22850358821ec1e7d968bc79003934ef" 
error: fuse-overlayfs not functional, make sure running with kernel >= 4.18: failed to mount fuse-overlayfs ({Type:fuse3.fuse-overlayfs Source:overlay Options:[lowerdir=/home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/lower2:/home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/lower1]}) on /home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/merged: mount helper [mount.fuse3 [overlay /home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/merged -o lowerdir=/home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/lower2:/home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1965694857/lower1 -t fuse-overlayfs]] failed: "": exec: "mount.fuse3": executable file not found in $PATH
```

Let's try again :) Manually this time, at least we get an "operation not permitted" error:

```bash
INFO[0000] containerd-fuse-overlayfs-grpc Version="v1.0.6" Revision="a705ae6f22850358821ec1e7d968bc79003934ef" 
WARN[0000] Failed to unmount check directory /home/sochat1_llnl_gov/.local/share/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs/fuseoverlayfs-check1832917374/merged  error="operation not permitted"
```

TODO: we really need to have the boot scripts working, and then at least I can get things started at the
same time (and the uid/gid changed then). When you are done:

```bash
$ make destroy
```
