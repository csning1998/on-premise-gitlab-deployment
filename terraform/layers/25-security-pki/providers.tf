
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.11.1"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-pki"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-pki/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-pki/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.sys_vault_endpoint
  ca_cert_file = local.bootstrap_ca_path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}
