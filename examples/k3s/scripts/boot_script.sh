#!/bin/bash

# This originally installed k3s, but since we want the logic to belong with Flux,
# we now do it there and use this tiny script to just install a quick set of
# dependencies that we need.

# Bind utils has nslookup to get ip address
dnf update -y 
dnf install -y wget bind-utils

# Put this somewhere everyone can access
wget -O /tmp/install-k3s.sh https://get.k3s.io
chmod o+rx /tmp/install-k3s.sh
