
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
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/60-provision-gitlab-platform"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/60-provision-gitlab-platform/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/60-provision-gitlab-platform/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

# Production Provider (Layer 10 Vault)
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

# GitLab Provider configuration using Personal Access Token (PAT)
provider "gitlab" {
  base_url    = "https://${local.gitlab_frontend_fqdn}/api/v4/"
  cacert_file = local.state.vault_pki.bootstrap_ca_b64.path
  token       = ephemeral.vault_kv_secret_v2.gitlab_pat.data["token"]
  # token       = var.gitlab_token
}
