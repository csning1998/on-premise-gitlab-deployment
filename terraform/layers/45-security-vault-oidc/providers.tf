
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/45-security-vault-oidc"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/45-security-vault-oidc/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/45-security-vault-oidc/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "vault" {
  alias        = "production"
  address      = local.vault_endpoint
  ca_cert_file = local.state.vault_pki.bootstrap_ca_b64.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}
