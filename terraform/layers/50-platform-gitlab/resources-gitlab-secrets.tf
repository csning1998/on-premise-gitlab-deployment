
# GitLab Internal Application Secrets (Rails, Shell, Gitaly, Root)
resource "random_password" "gitlab_internal" {
  for_each = toset(["rails-secret", "shell-secret", "gitaly-secret", "root-password"])
  length   = 32
  special  = false
}

# Vault Storage: Centralized Credentials Logic
# a. Postgres Credentials
resource "vault_kv_secret_v2" "gitlab_db_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/database"

  data_json = jsonencode({
    username = local.state.provision_databases.postgres_connection_info.username
    password = local.state.provision_databases.postgres_connection_info.password
    database = local.state.provision_databases.postgres_connection_info.database
    host     = local.state.provision_databases.postgres_connection_info.host
    port     = local.state.provision_databases.postgres_connection_info.port

    # TLS Context for the application
    tls = {
      crt = local.state.provision_databases.postgres_client_cert.crt
      key = local.state.provision_databases.postgres_client_cert.key
      ca  = local.state.provision_databases.postgres_client_cert.ca
    }
  })
}

# b. Redis Credentials
resource "vault_kv_secret_v2" "gitlab_redis_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    password = local.state.provision_databases.redis_connection_info.password
  })
}

# c. GitLab Internal Secrets
resource "vault_kv_secret_v2" "gitlab_internal_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key    = random_password.gitlab_internal["rails-secret"].result
    gitlab_shell_secret = random_password.gitlab_internal["shell-secret"].result
    gitaly_token        = random_password.gitlab_internal["gitaly-secret"].result
    root_password       = random_password.gitlab_internal["root-password"].result
  })
}
