
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
      version = "1.25.0"
    }
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
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
  minio_server      = "${data.terraform_remote_state.minio.outputs.service_vip}:${data.terraform_remote_state.minio.outputs.minio_api_port}"
  minio_user        = data.vault_kv_secret_v2.db_vars.data["minio_root_user"]
  minio_password    = data.vault_kv_secret_v2.db_vars.data["minio_root_password"]
  minio_ssl         = true
  minio_insecure    = false
  minio_cacert_file = "${path.root}/tls/minio-ca-bundle.crt"
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
    cert      = vault_pki_secret_backend_cert.gitlab_db_client.certificate
    key       = vault_pki_secret_backend_cert.gitlab_db_client.private_key
    sslinline = true
  }
}
