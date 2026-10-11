
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
    sshclient = {
      source = "local/csning1998-lab/sshclient"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/foundation-libvirt-resources"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/foundation-libvirt-resources/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/foundation-libvirt-resources/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "libvirt" {
  uri = "qemu:///system?socket=/var/run/libvirt/virtqemud-sock"
}

provider "sshclient" {}
