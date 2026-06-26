
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
  vault_secret_path_prefix = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor/app/s3_credentials"
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
    "postgres_exporter" = {
      password = data.vault_kv_secret_v2.db_vars.data["pg_exporter_password"]
      login    = true
      roles    = ["pg_monitor"]
    }
  }
}

# Persist Harbor database connection bundle to Vault
resource "vault_kv_secret_v2" "harbor_app_database" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor/app/database"
  data_json = jsonencode({
    username = module.harbor_db_init.users[var.db_init_config.db_user].name
    password = random_password.harbor_db_password.result
    database = module.harbor_db_init.databases[var.db_init_config.db_name].name
    host     = local.postgres_vip
    port     = local.postgres_rw_port
    tls = {
      crt = base64encode(vault_pki_secret_backend_cert.harbor_db_client.certificate)
      key = base64encode(vault_pki_secret_backend_cert.harbor_db_client.private_key)
      ca  = base64encode(vault_pki_secret_backend_cert.harbor_db_client.ca_chain)
    }
  })
}
