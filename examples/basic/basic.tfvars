# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# project_id, network_name, and region / zone are provided in Makefile

# Note that the name_prefix + instances determines the size of the cluster
# E.g., below would deploy gffw-compute-a-[001-003]

# This builds from the ../../build-images/bursted directory
compute_family = "flux-fw-bursted-x86-64"
compute_node_specs = [
  {
    name_prefix  = "gffw-compute-a"
    machine_arch = "x86-64"
    machine_type = "c2-standard-8"
    gpu_type     = null
    gpu_count    = 0
    compact      = false
    instances    = 3
    properties   = []
    boot_script  = <<BOOT_SCRIPT
#!/bin/sh

set -eEu -o pipefail

# This is already built into the image
fluxuser=flux
fluxuid=$(id -u $fluxuser)

# IMPORTANT - this needs to match the local cluster
fluxroot=/usr

echo "Flux username: flux"
echo "Flux install root: /usr"
export fluxroot

# Prepare NFS
dnf install nfs-utils -y

mkdir -p /var/nfs/home
chown nobody:nobody /var/nfs/home

ip_addr=$(hostname -I)

echo "/var/nfs/home *(rw,no_subtree_check,no_root_squash)" >> /etc/exports

firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent
firewall-cmd --reload

systemctl enable --now nfs-server rpcbind

# commands to be run as root
asFlux="sudo -u flux -E HOME=/home/flux -E PATH=$PATH"

# TODO we can allow custom logic here if needed

echo "flux ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
printf "flux user identifiers:\n$(id flux)\n"
printf "\nAs Flux prefix for flux commands: $asFlux\n"

export STATE_DIR=/var/lib/flux
mkdir -p /var/lib/flux
mkdir -p /usr/etc/flux/system/conf.d

# --cores=IDS Assign cores with IDS to each rank in R, so we  assign 0-(N-1) to each host
echo "flux R encode --hosts=gffw-compute-a-[001-003]"
flux R encode --hosts=gffw-compute-a-[001-003] --local > /usr/etc/flux/system/R
printf "\n📦 Resources\n"
cat /usr/etc/flux/system/R

mkdir -p /etc/flux/imp/conf.d/
cat <<EOT >> /etc/flux/imp/conf.d/imp.toml
[exec]
allowed-users = [ "flux", "root" ]
allowed-shells = [ "/usr/libexec/flux/flux-shell" ]
EOT

printf "\n🦊 Independent Minister of Privilege\n"
cat /etc/flux/imp/conf.d/imp.toml

cat <<EOT >> /tmp/system.toml
[exec]
imp = "/usr/libexec/flux/flux-imp"

# Allow users other than the instance owner (guests) to connect to Flux
# Optionally, root may be given "owner privileges" for convenience
[access]
allow-guest-user = true
allow-root-owner = true

# Point to shared network certificate generated flux-keygen(1).
# Define the network endpoints for Flux's tree based overlay network
# and inform Flux of the hostnames that will start flux-broker(1).
[bootstrap]
curve_cert = "/usr/etc/flux/system/curve.cert"

default_port = 8050
default_bind = "tcp://eth0:%p"
default_connect = "tcp://%h:%p"

hosts = [{host="gffw-compute-a-[001-003]"}]

# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"

# Point to resource definition generated with flux-R(1).
# Uncomment to exclude nodes (e.g. mgmt, login), from eligibility to run jobs.
[resource]
path = "/usr/etc/flux/system/R"

# Remove inactive jobs from the KVS after one week.
[job-manager]
inactive-age-limit = "7d"
EOT

mv /tmp/system.toml /usr/etc/flux/system/conf.d/system.toml

echo "🐸 Broker Configuration"
cat /usr/etc/flux/system/conf.d/system.toml

# If we are communicating via the flux uri this service needs to be started
chmod u+s /usr/libexec/flux/flux-imp
chmod 4755 /usr/libexec/flux/flux-imp
chmod 0644 /etc/flux/imp/conf.d/imp.toml
# sudo chown -R flux:flux /usr/etc/flux/system/conf.d

cat << "PYTHON_DECODING_SCRIPT" > /tmp/convert_curve_cert.py
#!/usr/bin/env python3
import sys
import base64

string = sys.argv[1]
dest = sys.argv[2]
with open(dest, 'w') as fd:
    fd.write(base64.b64decode(string).decode('utf-8'))
PYTHON_DECODING_SCRIPT

python3 /tmp/convert_curve_cert.py "IyAgICoqKiogIEdlbmVyYXRlZCBvbiAyMDIzLTA3LTE2IDIwOjM5OjIxIGJ5IENaTVEgICoqKioK
IyAgIFplcm9NUSBDVVJWRSAqKlNlY3JldCoqIENlcnRpZmljYXRlCiMgICBETyBOT1QgUFJPVklE
RSBUSElTIEZJTEUgVE8gT1RIRVIgVVNFUlMgbm9yIGNoYW5nZSBpdHMgcGVybWlzc2lvbnMuCgpt
ZXRhZGF0YQogICAgbmFtZSA9ICJlODZhMTM1MWZiY2YiCiAgICBrZXlnZW4uY3ptcS12ZXJzaW9u
ID0gIjQuMi4wIgogICAga2V5Z2VuLnNvZGl1bS12ZXJzaW9uID0gIjEuMC4xOCIKICAgIGtleWdl
bi5mbHV4LWNvcmUtdmVyc2lvbiA9ICIwLjUxLjAtMTM1LWdiMjA0NjBhNmUiCiAgICBrZXlnZW4u
aG9zdG5hbWUgPSAiZTg2YTEzNTFmYmNmIgogICAga2V5Z2VuLnRpbWUgPSAiMjAyMy0wNy0xNlQy
MDozOToyMSIKICAgIGtleWdlbi51c2VyaWQgPSAiMTAwMiIKICAgIGtleWdlbi56bXEtdmVyc2lv
biA9ICI0LjMuMiIKY3VydmUKICAgIHB1YmxpYy1rZXkgPSAidVEmXnkrcDo3XndPUUQ8OkldLShL
RDkjbVo2I0wmeSlZTGUzTXBOMSIKICAgIHNlY3JldC1rZXkgPSAiVkUjQHBKKXgtRUE/WntrS1cx
ZWY9dTw+WCpOR2hKJjUqallNRSUjQCIKCg==" /tmp/curve.cert

mv /tmp/curve.cert /usr/etc/flux/system/curve.cert
chmod u=r,g=,o= /usr/etc/flux/system/curve.cert
chown flux:flux /usr/etc/flux/system/curve.cert
# /usr/sbin/create-munge-key
service munge start

# The rundir needs to be created first, and owned by user flux
# Along with the state directory and curve certificate
mkdir -p /run/flux
sudo chown -R flux:flux /run/flux

# Remove group and other read
chmod o-r /usr/etc/flux/system/curve.cert
chmod g-r /usr/etc/flux/system/curve.cert
chown -R $fluxuid /run/flux /var/lib/flux /usr/etc/flux/system/curve.cert

printf "\n✨ Curve certificate generated by helper pod\n"
cat /usr/etc/flux/system/curve.cert

mkdir -p /etc/flux/manager

cat << "FIRST_BOOT_UNIT" > /etc/systemd/system/flux-start.service
[Unit]
Description=Flux message broker
Wants=munge.service

[Service]
Type=simple
NotifyAccess=main
TimeoutStopSec=90
KillMode=mixed
ExecStart=/usr/bin/flux start --broker-opts --config /usr/etc/flux/system/conf.d -Stbon.fanout=256  -Srundir=/run/flux -Sbroker.rc2_none -Sstatedir=/var/lib/flux -Slocal-uri=local:///run/flux/local -Stbon.connect_timeout=5s -Stbon.zmqdebug=1  -Slog-stderr-level=7 -Slog-stderr-mode=local
SyslogIdentifier=flux
Restart=always
RestartSec=5s
RestartPreventExitStatus=42
SuccessExitStatus=42
User=flux
Group=flux
PermissionsStartOnly=true
Delegate=yes

[Install]
WantedBy=multi-user.target
FIRST_BOOT_UNIT

systemctl enable flux-start.service
systemctl start flux-start.service

# This enables NFS
nfsmounts=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs-mounts" -H "Metadata-Flavor: Google")

if [[ "X$nfsmounts" != "X" ]]; then
    echo "Enabling NFS mounts"
    share=$(echo $nfsmounts | jq -r '.share')
    mountpoint=$(echo $nfsmounts | jq -r '.mountpoint')

    bash -c "sudo echo $share $mountpoint nfs defaults,hard,intr,_netdev 0 0 >> /etc/fstab"
    mount -a
fi
BOOT_SCRIPT

  },
]
compute_scopes = ["cloud-platform"]
