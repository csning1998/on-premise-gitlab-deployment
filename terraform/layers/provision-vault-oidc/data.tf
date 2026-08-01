
data "terraform_remote_state" "vault_sys" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-vault-frontend" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

data "terraform_remote_state" "keycloak_provisioning" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/provision-keycloak-oidc" })
}

# Read OIDC Client credentials from Vault (Created in L40)
data "vault_kv_secret_v2" "keycloak_vault_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/keycloak/oidc/clients/vault_frontend"
}
