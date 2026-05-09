
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
  }
}

module "minio_gitlab_config" {
  source = "../../modules/configuration/minio-bucket-setup"

  providers = {
    vault = vault.production
  }

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "on-premise-gitlab-deployment/gitlab/app/s3_credentials"
  minio_server_url         = local.minio_url
}

# Persist generated database credentials to Vault (SSoT)
resource "vault_kv_secret_v2" "gitlab_app_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app"

  data_json = jsonencode({
    gitlab_pg_db_password = random_password.gitlab_db_password.result
  })
}
