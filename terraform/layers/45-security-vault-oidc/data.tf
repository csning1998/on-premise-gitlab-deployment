
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "vault_sys" {
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

data "terraform_remote_state" "keycloak_provisioning" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-keycloak-oidc" })
}

# Read OIDC Client credentials from Vault (Created in L40)
data "vault_kv_secret_v2" "keycloak_vault_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/keycloak/oidc/clients/vault_frontend"
}
