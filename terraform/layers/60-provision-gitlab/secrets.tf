
resource "random_password" "gitlab_internal" {
  for_each = toset(["rails-secret", "shell-secret", "gitaly-secret", "root-password"])
  length   = 32
  special  = false
}

resource "vault_generic_secret" "gitlab_internal_keys" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key    = random_password.gitlab_internal["rails-secret"].result
    gitlab_shell_secret = random_password.gitlab_internal["shell-secret"].result
    gitaly_token        = random_password.gitlab_internal["gitaly-secret"].result
    root_password       = random_password.gitlab_internal["root-password"].result
  })
}

resource "kubernetes_secret" "gitlab_postgres_tls" {
  metadata {
    name      = "gitlab-postgres-tls"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  data = {
    "tls.crt" = local.gitlab_db.tls.crt
    "tls.key" = local.gitlab_db.tls.key
    "ca.crt"  = local.gitlab_db.tls.ca
  }
}

# Write Redis connection info to Vault App Path for record-keeping and application reference
resource "vault_generic_secret" "gitlab_redis_keys" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    # Use variables to drive IP & Port
    host     = local.redis_vip
    port     = local.redis_port
    password = local.redis_password
    scheme   = "rediss"
  })
}
