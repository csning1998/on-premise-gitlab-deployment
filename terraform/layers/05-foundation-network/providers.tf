
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
  }
  backend "http" {}
}

provider "libvirt" {
  uri = "qemu:///system"
}
