
data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-vault-bootstrapper" })
}

data "terraform_remote_state" "vault_sys" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-vault-frontend" })
}

# Production Vault Initial Credentials
data "vault_kv_secret_v2" "prod_credential" {
  provider = vault.bootstrapper
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/credentials"
}
