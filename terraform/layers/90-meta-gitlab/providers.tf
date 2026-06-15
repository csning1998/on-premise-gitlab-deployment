
terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "19.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/90-meta-gitlab"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/90-meta-gitlab/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/90-meta-gitlab/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "vault" {
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

provider "gitlab" {
  token = ephemeral.vault_kv_secret_v2.gitlab_token.data["gitlab_pat"]
}
