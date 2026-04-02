
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
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
  ca_cert_file = local.state.vault_pki.bootstrap_ca.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
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
