
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

data "terraform_remote_state" "keycloak_oidc" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-keycloak-oidc" })
}

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

ephemeral "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["frontend"]
}

data "vault_kv_secret_v2" "keycloak_harbor_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/keycloak/oidc/clients/harbor_frontend"
}
