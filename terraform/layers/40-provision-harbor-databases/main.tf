
# PKI Client Certificate for Postgres Provisioning
resource "vault_pki_secret_backend_cert" "harbor_db_client" {
  provider    = vault.production
  backend     = local.state.vault_pki.pki_configuration.path
  name        = local.state.vault_pki.pki_configuration.pki_roles["harbor-frontend"].name
  common_name = local.state.vault_pki.pki_configuration.pki_roles["harbor-frontend"].allowed_domains[0]
  ttl         = local.state.vault_pki.pki_configuration.lease_durations.default
}

module "minio_harbor_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = local.minio_url
}

# Random password for Harbor database role
resource "random_password" "harbor_db_password" {
  length  = 24
  special = false
}

# Harbor DB Initialization
module "harbor_db_init" {
  source = "../../modules/configuration/patroni-init"

  databases = {
    (var.db_init_config.db_name) = {
      owner = var.db_init_config.db_user
    }
  }

  users = {
    (var.db_init_config.db_user) = {
      password = random_password.harbor_db_password.result
      roles    = []
    }
  }
}

# Random password for Harbor admin
resource "random_password" "harbor_admin_password" {
  length  = 24
  special = false
}

# Persist generated database credentials to Vault (SSoT)
resource "vault_kv_secret_v2" "harbor_db_password" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/app"
  data_json = jsonencode({
    harbor_pg_db_password = random_password.harbor_db_password.result
    harbor_admin_password = random_password.harbor_admin_password.result
  })
}
