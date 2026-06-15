
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
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.26.0"
    }
  }
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-databases"
    lock_address   = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-databases/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82448331/terraform/state/40-provision-harbor-databases/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
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

provider "minio" {
  minio_server      = "${local.state.minio.service_vip}:${local.state.minio.minio_api_port}"
  minio_user        = ephemeral.vault_kv_secret_v2.minio_vars.data["minio_root_user"]
  minio_password    = ephemeral.vault_kv_secret_v2.minio_vars.data["minio_root_password"]
  minio_ssl         = true
  minio_insecure    = false
  minio_cacert_file = local.state.vault_pki.bootstrap_ca_b64.path
}

provider "postgresql" {
  scheme   = "postgres"
  host     = local.postgres_vip
  port     = local.postgres_rw_port
  username = "postgres"
  password = local.postgres_password

  sslmode         = "require"
  connect_timeout = 15

  clientcert {
    cert      = vault_pki_secret_backend_cert.harbor_db_client.certificate
    key       = vault_pki_secret_backend_cert.harbor_db_client.private_key
    sslinline = true
  }
}
