
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
}


# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.sys_vault_addr
  ca_cert_file = local.state.vault_sys.ca_cert_path

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
  url      = "https://${data.terraform_remote_state.harbor_bootstrapper.outputs.service_vip}"
  username = "admin"
  password = data.vault_generic_secret.harbor_bootstrapper.data["harbor_bootstrapper_admin_password"]
}
