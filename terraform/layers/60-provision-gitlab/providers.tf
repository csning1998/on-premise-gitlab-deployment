
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "18.11.0"
    }
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
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

# GitLab Provider configuration using Personal Access Token (PAT)
provider "gitlab" {
  base_url    = "https://${local.gitlab_fqdn}/api/v4/"
  cacert_file = local.state.vault_pki.bootstrap_ca_b64.path
  token       = ephemeral.vault_kv_secret_v2.gitlab_internal.data["token"]
  # token       = var.gitlab_token
}
