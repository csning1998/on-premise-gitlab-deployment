
# Random password for GitLab
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

# Enable necessary extensions (GitLab requirements) requires Superuser privileges, so the Provider must use postgres login
resource "postgresql_extension" "pg_trgm" {
  name     = "pg_trgm"
  database = postgresql_database.gitlabhq_production.name
}

resource "postgresql_extension" "btree_gist" {
  name     = "btree_gist"
  database = postgresql_database.gitlabhq_production.name
}

# SoC: Write generated password back to Vault
# Use subpath to avoid overwriting the manually created gitlab/app (which contains the root password)
resource "vault_generic_secret" "gitlab_db_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/database"

  data_json = jsonencode({
    username = postgresql_role.gitlab.name
    password = postgresql_role.gitlab.password
    database = postgresql_database.gitlabhq_production.name
    # Also record host
    host = data.terraform_remote_state.gitlab_postgres.outputs.gitlab_postgres_virtual_ip
    port = data.terraform_remote_state.gitlab_postgres.outputs.gitlab_postgres_haproxy_rw_port
  })
}

# Create Kubernetes Secret for Helm Chart, this will be mounted to GitLab's Webservice/Sidekiq/Migrations
resource "kubernetes_secret" "gitlab_postgres_password" {
  metadata {
    name      = "gitlab-postgres-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    # GitLab Helm Chart default key is "postgresql-password" or "password"
    password              = postgresql_role.gitlab.password
    "postgresql-password" = postgresql_role.gitlab.password
  }
}
