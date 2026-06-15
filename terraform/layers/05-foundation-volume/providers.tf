
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/05-foundation-volume"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/05-foundation-volume/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/05-foundation-volume/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
