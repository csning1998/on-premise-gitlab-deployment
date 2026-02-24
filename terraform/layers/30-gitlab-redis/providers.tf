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

# Bootstrap Provider (Podman Vault)
provider "vault" {
  alias           = "bootstrapper"
  address         = var.vault_dev_addr
  token           = trimspace(file(abspath("${path.root}/../../../vault/keys/root-token.txt")))
  skip_tls_verify = true
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  address      = local.sys_vault_addr
  token        = data.vault_generic_secret.prod_credential.data["prod_vault_root_token"]
  ca_cert_file = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca_path
}
