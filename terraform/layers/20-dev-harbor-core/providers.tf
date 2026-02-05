
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "vault" {
  address      = local.vault_address
  ca_cert_file = abspath("${path.root}/../10-vault-core/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}
