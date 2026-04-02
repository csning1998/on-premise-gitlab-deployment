
# PKI Client Certificate for Postgres Provisioning & Application Access
# TODO: This certificate uses the 'gitlab-frontend' role identity.
#       When PostgreSQL RBAC is hardened with cert-based auth (i.e., pg_hba.conf clientcert=verify-full),
#       a dedicated 'gitlab-provisioner' PKI role should be created and used here instead.
resource "vault_pki_secret_backend_cert" "gitlab_db_client" {

  provider = vault.production
  backend  = local.state.vault_pki.pki_configuration.path
  name     = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].name

  common_name = local.state.vault_pki.pki_configuration.component_roles["gitlab-frontend"].allowed_domains[0]

  ttl = "2160h" # 90 Days
}

# Random password for GitLab application
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

# Write generated credentials and TLS context back to Vault
resource "vault_generic_secret" "gitlab_db_keys" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/app/database"

  data_json = jsonencode({
    username = postgresql_role.gitlab.name
    password = postgresql_role.gitlab.password
    database = postgresql_database.gitlabhq_production.name
    host     = local.postgres_vip
    port     = local.postgres_rw_port

    # TLS Context for the application
    tls = {
      crt = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.certificate)
      key = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.private_key)
      ca  = base64encode(vault_pki_secret_backend_cert.gitlab_db_client.ca_chain)
    }
  })
}
