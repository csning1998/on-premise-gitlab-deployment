
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
      password = local.harbor_pg_db_password
      roles    = []
    }
  }
}
