# Flux Framework Cluster Module

**IMPORTANT** this set of modules is not in use - we are opting to use a simpler setup with one node (under burst).

This module handles the deployment of Flux as the native resource manager on a cluster of GCP compute instances.
It is a variant of [these original recipes](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/main/fluxfw-gcp/tf)
We have maintained the same [LICENSE](../LICENSE) and headers.

This module will create:

- a single `management node`
- one or more `login nodes`
- one or more `compute nodes`

submodules are provided for creating the components. See the [modules]() directory for the individual submodules usage.

## Usage

You can go the the examples directory, however the usage of this module could be like this in your own main.tf file

```hcl
module "cluster" {
    source = "github.com/converged-computing/flux-terraform-gcp//tf?ref=add-tf"

    project_id           = var.project_id
    region               = var.region

    service_account_emails = {
        manager = data.google_compute_default_service_account.default.email
        login   = data.google_compute_default_service_account.default.email
        compute = data.google_compute_default_service_account.default.email
    }

    subnetwork           = module.network.subnets_self_links[0]
    cluster_storage      = {
        mountpoint = "/home"
        share      = "${module.nfs_server_instance.instances_details.0.network_interface.0.network_ip}:/var/nfs/home"
    }

    broker_config        = var.broker_config
    manager_name_prefix  = var.manager_name_prefix
    manager_machine_type = var.manager_machine_type
    manager_family       = var.manager_family
    manager_scopes       = var.manager_scopes

    login_family         = var.login_family
    login_node_specs     = var.login_node_specs
    login_scopes         = var.login_scopes

    compute_family       = var.compute_family
    compute_node_specs   = var.compute_node_specs
    compute_scopes       = var.compute_scopes
}
```

where Terraform _remote state_ references are used to supply the project/region, IAM, network, and storage values.
See the [variables.tf](variables.tf) file for complete variables and descriptions.
