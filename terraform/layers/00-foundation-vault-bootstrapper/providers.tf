
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/00-foundation-vault-bootstrapper"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/00-foundation-vault-bootstrapper/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/00-foundation-vault-bootstrapper/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

# The target Vault being configured (Bootstrapper/Initial Vault)
provider "vault" {
  address      = var.vault_dev_addr
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")
}
