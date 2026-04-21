
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    # gitlab = {
    #   source  = "gitlabhq/gitlab"
    #   version = "17.8.0"
    # }
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
  ca_cert_file = local.state.vault_pki.bootstrap_ca.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}

# provider "gitlab" {
#   base_url = "https://${local.gitlab_fqdn}/api/v4/"
#   password = local.gitlab_root_password
#   username = "root"
# }
