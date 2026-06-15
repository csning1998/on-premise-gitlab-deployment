
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/10-shared-load-balancer-frontend"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/10-shared-load-balancer-frontend/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/10-shared-load-balancer-frontend/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

# Default for Bootstrap, connect to Local Podman Vault
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
