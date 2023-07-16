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

module "cluster" {
  source     = "github.com/converged-computing/flux-terraform-gcp//burst"
  project_id = var.project_id
  region     = var.region

  service_account_emails = {
    manager = data.google_compute_default_service_account.default.email
    login   = data.google_compute_default_service_account.default.email
    compute = data.google_compute_default_service_account.default.email
  }

  subnetwork = module.network.subnets_self_links[0]
  cluster_storage = {
    mountpoint = "/home"
    share      = "${module.nfs_server_instance.instances_details.0.network_interface.0.network_ip}:/var/nfs/home"
  }
  compute_node_specs = var.compute_node_specs
  compute_scopes     = var.compute_scopes
  family             = var.compute_family
}
