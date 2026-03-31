
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = "3.12.0"
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

provider "minio" {
  minio_server   = "${data.terraform_remote_state.minio_infra.outputs.service_vip}:${data.terraform_remote_state.minio_infra.outputs.minio_api_port}"
  minio_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
  minio_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
  minio_ssl      = true
  minio_insecure = true
}
