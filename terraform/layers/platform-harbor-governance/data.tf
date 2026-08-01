
data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-vault-frontend" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

data "terraform_remote_state" "credentials" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-credentials" })
}

data "terraform_remote_state" "keycloak_oidc" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/provision-keycloak-oidc" })
}

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/provision-harbor-bootstrapper-frontend" })
}

ephemeral "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["frontend"]
}

data "vault_kv_secret_v2" "keycloak_harbor_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/keycloak/oidc/clients/harbor_frontend"
}
