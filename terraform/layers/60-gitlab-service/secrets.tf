
resource "random_password" "gitlab_internal" {
  for_each = toset(["rails-secret", "shell-secret", "gitaly-secret", "root-password"])
  length   = 32
  special  = false
}

resource "vault_generic_secret" "gitlab_internal_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key    = random_password.gitlab_internal["rails-secret"].result
    gitlab_shell_secret = random_password.gitlab_internal["shell-secret"].result
    gitaly_token        = random_password.gitlab_internal["gitaly-secret"].result
    root_password       = random_password.gitlab_internal["root-password"].result
  })
}

resource "vault_pki_secret_backend_cert" "gitlab_db_client" {
  backend = data.terraform_remote_state.vault_pki.outputs.pki_configuration.path
  name    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["gitlab-frontend"].name

  common_name = "gitlab.iac.local"

  ttl = "2160h" # 90 Days
}

resource "kubernetes_secret" "gitlab_postgres_tls" {
  metadata {
    name      = "gitlab-postgres-tls"
    namespace = var.gitlab_helm_config.namespace
  }

  data = {
    "tls.crt" = vault_pki_secret_backend_cert.gitlab_db_client.certificate
    "tls.key" = vault_pki_secret_backend_cert.gitlab_db_client.private_key
    "ca.crt"  = vault_pki_secret_backend_cert.gitlab_db_client.ca_chain
  }
}

# Write Redis connection info to Vault App Path for record-keeping and application reference
resource "vault_generic_secret" "gitlab_redis_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    # Use variables to drive IP & Port
    host     = data.terraform_remote_state.redis.outputs.gitlab_redis_virtual_ip
    port     = data.terraform_remote_state.redis.outputs.gitlab_redis_haproxy_stats_port
    password = local.redis_password
    scheme   = "rediss"
  })
}

