
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
    password = local.gitlab_db.password
    database = local.state.provision_databases.postgres_connection_info.database
    host     = local.state.provision_databases.postgres_connection_info.host
    port     = local.state.provision_databases.postgres_connection_info.port

    # TLS Context for the application
    tls = {
      crt = local.state.provision_databases.postgres_client_cert_b64.crt_b64
      key = local.state.provision_databases.postgres_client_cert_b64.key_b64
      ca  = local.state.provision_databases.postgres_client_cert_b64.ca_b64
    }
  })
}

# b. Redis Credentials
resource "vault_kv_secret_v2" "gitlab_redis_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    password = local.redis_password
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

# OIDC OmniAuth Configuration Secret
# Ref: https://docs.gitlab.com/charts/charts/globals.html#omniauth
resource "kubernetes_secret" "gitlab_keycloak_oidc" {
  metadata {
    name      = "gitlab-keycloak-oidc"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }
  data = {
    "provider" = yamlencode({
      name  = "openid_connect"
      label = "Keycloak"
      args = {
        name               = "openid_connect"
        scope              = ["openid", "profile", "email"]
        response_type      = "code"
        issuer             = data.terraform_remote_state.keycloak_oidc.outputs.issuer_url
        discovery          = true
        client_signing_alg = "RS256"
        client_options = {
          identifier   = "gitlab-infra"
          secret       = data.vault_kv_secret_v2.keycloak_gitlab_client.data["client_secret"]
          redirect_uri = "https://${local.fqdn_gitlab}/users/auth/openid_connect/callback"
        }
      }
    })
  }
}
