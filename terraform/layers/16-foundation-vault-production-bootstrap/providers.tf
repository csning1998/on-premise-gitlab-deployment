
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

# Provider for retrieving credentials from local Seed Vault
provider "vault" {
  alias        = "bootstrapper"
  address      = data.terraform_remote_state.vault_bootstrapper.outputs.vault_addr
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_bootstrapper.outputs.role_id
      secret_id = data.terraform_remote_state.vault_bootstrapper.outputs.secret_id
    }
  }
  skip_child_token = true
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias            = "production"
  address          = local.sys_vault_addr
  token            = data.vault_kv_secret_v2.prod_credential.data["prod_vault_root_token"]
  ca_cert_file     = local.ca_cert_path
  skip_child_token = true
}
