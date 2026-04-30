
# 1. Generate Random Authentication Token for Runner
resource "random_password" "runner_token" {
  length  = 32
  special = false
}

# 2. Store Token in Vault for SSoT
resource "vault_kv_secret_v2" "runner_token" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/runner-token"

  data_json = jsonencode({
    token = random_password.runner_token.result
  })
}
