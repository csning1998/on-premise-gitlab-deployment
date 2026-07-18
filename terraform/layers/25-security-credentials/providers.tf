
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-credentials"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-credentials/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/25-security-credentials/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "vault" {
  alias        = "production"
  address      = local.sys_vault_endpoint
  ca_cert_file = local.ca_cert_path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
      secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
    }
  }
  skip_child_token = true
}

# Bootstrap Provider (Bootstrap Vault), used to mirror bootstrap-time-only secrets
# (e.g. haproxy_stats_pass) into Production Vault for post-L15 consumers.
provider "vault" {
  alias        = "bootstrap"
  address      = local.state.vault_bootstrapper.vault_dev_endpoint
  ca_cert_file = local.state.vault_bootstrapper.vault_dev_ca_cert_path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_bootstrapper.role_id
      secret_id = local.state.vault_bootstrapper.secret_id
    }
  }
  skip_child_token = true
}
