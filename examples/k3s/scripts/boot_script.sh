#!/bin/bash

# This originally installed k3s, but since we want the logic to belong with Flux,
# we now do it there and use this tiny script to just install a quick set of
# dependencies that we need.

# Bind utils has nslookup to get ip address
dnf update -y 
dnf install -y wget bind-utils

# Put this somewhere we can inspect later. Likely for our production
# setup we want to freeze the version we choose, meaning: 
# 1. choose a commit to export to the environment, one of INSTALL_K3S_VERSION or INSTALL_K3S_COMMIT
# 2. save the install script somewhere for provenance, etc.
# 3. note you can also skip starting / enabling the services
curl -sfL https://get.k3s.io | sh -
