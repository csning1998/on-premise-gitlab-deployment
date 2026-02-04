
# Write Redis connection info to Vault App Path for record-keeping and application reference
resource "vault_generic_secret" "gitlab_redis_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    # Use variables to drive IP & Port
    host = data.terraform_remote_state.gitlab_redis.outputs.gitlab_redis_virtual_ip
    # host     = "172.16.141.200" # TODO: Use variables to drive IP & Port
    port     = data.terraform_remote_state.gitlab_redis.outputs.gitlab_redis_haproxy_stats_port
    password = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    scheme   = "rediss"
  })
}

# Kubernetes Secret for Helm Chart
resource "kubernetes_secret" "gitlab_redis_password" {
  metadata {
    name      = "gitlab-redis-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    # GitLab Helm Chart supports Secret Name & Key by default
    password = data.vault_generic_secret.db_vars.data["redis_requirepass"]
  }
}
