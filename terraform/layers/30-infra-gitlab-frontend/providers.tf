
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/30-infra-gitlab-frontend"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/30-infra-gitlab-frontend/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/30-infra-gitlab-frontend/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.sys_vault_endpoint
  ca_cert_file = local.vault_pki_cert_path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
      secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
    }
  }
  skip_child_token = true
}
