terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "vault" {
  address      = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
  ca_cert_file = abspath("${path.root}/../10-vault-raft/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}
