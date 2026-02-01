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
    minio = {
      source  = "aminueza/minio"
      version = "3.12.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "vault" {
  address      = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  ca_cert_file = abspath("${path.root}/../10-vault-core/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}

provider "minio" {
  minio_server   = "${var.gitlab_minio_compute.haproxy_config.virtual_ip}:9000"
  minio_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
  minio_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
  minio_ssl      = true
  minio_insecure = true
}
