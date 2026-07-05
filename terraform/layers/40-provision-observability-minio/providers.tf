
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
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-observability-minio"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-observability-minio/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-observability-minio/lock"
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
      role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
      secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
    }
  }
  skip_child_token = true
}

provider "minio" {
  minio_server      = "${data.terraform_remote_state.minio.outputs.service_vip}:${data.terraform_remote_state.minio.outputs.minio_api_port}"
  minio_user        = ephemeral.vault_kv_secret_v2.minio_vars.data["minio_root_user"]
  minio_password    = ephemeral.vault_kv_secret_v2.minio_vars.data["minio_root_password"]
  minio_ssl         = true
  minio_insecure    = false
  minio_cacert_file = local.state.vault_pki.bootstrap_ca_b64.path
}
