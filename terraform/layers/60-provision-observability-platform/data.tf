
data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/15-shared-vault-frontend" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

data "terraform_remote_state" "credentials" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-credentials" })
}

data "terraform_remote_state" "observability_platform" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/50-platform-observability-frontend" })
}

ephemeral "vault_kv_secret_v2" "grafana_admin" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["observability"]["frontend"]
}
