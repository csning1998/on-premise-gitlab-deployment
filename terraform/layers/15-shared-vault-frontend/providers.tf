
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/15-shared-vault-frontend"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/15-shared-vault-frontend/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/15-shared-vault-frontend/lock"
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
