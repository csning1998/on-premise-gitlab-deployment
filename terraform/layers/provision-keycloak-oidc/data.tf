

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

data "terraform_remote_state" "keycloak" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-keycloak-frontend" })
}

ephemeral "vault_kv_secret_v2" "keycloak_admin" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["keycloak"]["frontend"]
}
