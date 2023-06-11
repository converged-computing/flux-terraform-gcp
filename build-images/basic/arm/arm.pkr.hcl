packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}


variable "enable_secure_boot" {
  type    = bool
  default = true
}

variable "machine_architecture" {
  type    = string
  default = "arm64"
}

variable "machine_type" {
  type    = string
  default = "t2a-standard-16"
}

variable "project_id" {
  type    = string
  default = "llnl-flux"
}

variable "source_image" {
  type    = string
  default = "rocky-linux-8-optimized-gcp-arm64-v20230615"
}

variable "source_image_project_id" {
  type    = string
  default = "rocky-linux-cloud"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

# "timestamp" template function replacement
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "flux-compute-arm" {
  project_id              = var.project_id
  source_image            = var.source_image
  source_image_project_id = [var.source_image_project_id]
  zone                    = var.zone
  image_name              = "flux-fw-compute-${var.machine_architecture}-v{{timestamp}}"
  image_family            = "flux-fw-compute-${var.machine_architecture}"
  image_description       = "flux-fw-compute"
  machine_type            = var.machine_type
  disk_size               = 256
  subnetwork              = var.subnetwork
  tags                    = ["packer", "flux", "compute", "arm", "${var.machine_architecture}"]
  startup_script_file     = "startup-script.sh"
  ssh_username            = "rocky"
  enable_secure_boot      = var.enable_secure_boot
}

build {
  sources = ["sources.googlecompute.flux-compute-arm"]
}
