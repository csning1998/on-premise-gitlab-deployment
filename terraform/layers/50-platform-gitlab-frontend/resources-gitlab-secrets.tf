
# Vault Storage: Centralized Credentials Logic
# a. Redis Credentials
resource "vault_kv_secret_v2" "gitlab_redis_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/gitlab/app/redis"

  data_json = jsonencode({
    password = local.redis_password
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
