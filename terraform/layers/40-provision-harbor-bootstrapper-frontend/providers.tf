
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.1"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-bootstrapper-frontend"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-bootstrapper-frontend/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-bootstrapper-frontend/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}


# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.sys_vault_addr
  ca_cert_file = local.state.vault_pki.bootstrap_ca_b64.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
      secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
    }
  }
  skip_child_token = true
}

provider "harbor" {
  url      = "https://${data.terraform_remote_state.harbor_bootstrapper.outputs.bstrap_harbor_fqdn}"
  username = "admin"
  password = ephemeral.vault_kv_secret_v2.harbor_bootstrapper.data["harbor_bootstrapper_admin_password"]
}
