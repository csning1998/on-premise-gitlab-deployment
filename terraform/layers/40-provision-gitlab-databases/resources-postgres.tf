
# PKI Client Certificate for Postgres Provisioning & Application Access
# This resource remains in Layer 40 because the postgresql provider
# requires it to establish a secure TLS connection during provisioning.
resource "vault_pki_secret_backend_cert" "gitlab_db_client" {
  provider = vault.production
  backend  = local.state.vault_pki.pki_configuration.path
  name     = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].name

  common_name = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].allowed_domains[0]

  ttl = "2160h" # 90 Days
}

# Random password for GitLab database role
resource "random_password" "gitlab_db_password" {
  length  = 24
  special = false
}

# GitLab DB Initialization via Module
module "gitlab_db_init" {
  source = "../../modules/configuration/patroni-full-init"

  pg_host               = local.postgres_vip
  pg_port               = local.postgres_rw_port
  pg_superuser          = "postgres"
  pg_superuser_password = local.postgres_password

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
