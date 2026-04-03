
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

# GitLab Role
resource "postgresql_role" "gitlab" {
  name            = "gitlab"
  login           = true
  password        = random_password.gitlab_db_password.result
  superuser       = false
  create_database = false
}

# GitLab Database
resource "postgresql_database" "gitlabhq_production" {
  name     = "gitlabhq_production"
  owner    = postgresql_role.gitlab.name
  encoding = "UTF8"
}

# Enable necessary extensions
resource "postgresql_extension" "pg_trgm" {
  name     = "pg_trgm"
  database = postgresql_database.gitlabhq_production.name
}

resource "postgresql_extension" "btree_gist" {
  name     = "btree_gist"
  database = postgresql_database.gitlabhq_production.name
}
