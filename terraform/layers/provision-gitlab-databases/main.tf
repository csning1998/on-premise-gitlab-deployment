
# PKI Client Certificate for Postgres Provisioning & Application Access
# This resource remains in Layer 40 because the postgresql provider
# requires it to establish a secure TLS connection during provisioning.
resource "vault_pki_secret_backend_cert" "gitlab_db_client" {
  provider    = vault.production
  backend     = local.state.vault_pki.pki_configuration.path
  name        = local.state.vault_pki.pki_configuration.pki_roles["gitlab-frontend"].name
  common_name = local.state.vault_pki.pki_configuration.pki_roles["gitlab-frontend"].allowed_domains[0]
  ttl         = local.state.vault_pki.pki_configuration.lease_durations.default
}

# Random password for GitLab database role
resource "random_password" "gitlab_db_password" {
  length  = 24
  special = false
}

# GitLab DB Initialization via Module
module "gitlab_db_init" {
  source = "../../modules/configuration/patroni-init"

  extension_drop_cascade = var.extension_drop_cascade

  databases = {
    "gitlabhq_production" = {
      owner      = "gitlab"
      extensions = ["pg_trgm", "btree_gist"]
    }
  }

  users = {
    "gitlab" = {
      password        = random_password.gitlab_db_password.result
      login           = true
      superuser       = false
      create_database = false
    }
    "postgres_exporter" = {
      password = data.vault_kv_secret_v2.db_vars.data["pg_exporter_password"]
      login    = true
      roles    = ["pg_monitor"]
    }
  }
}


module "minio_gitlab_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/s3_credentials"
  minio_server_url         = local.minio_url
}

module "minio_gitlab_prometheus_account" {
  source = "../../modules/configuration/minio-prometheus-account"

  providers = {
    vault.production = vault.production
  }

  user_name         = var.gitlab_minio_prometheus_account["gitlab-minio-prometheus"].user_name
  vault_secret_path = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/minio_prometheus"
}

# Persist generated database credentials to Vault (SSoT)
resource "vault_kv_secret_v2" "gitlab_app_database" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/database"

  data_json = jsonencode({
    username = module.gitlab_db_init.users["gitlab"].name
    password = random_password.gitlab_db_password.result
    database = module.gitlab_db_init.databases["gitlabhq_production"].name
    host     = local.postgres_vip
    port     = local.postgres_rw_port
    tls = {
      crt = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.certificate)
      key = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.private_key)
      ca  = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.ca_chain)
    }
  })
}
