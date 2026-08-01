
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

# Fetch GitLab Admin/Root credentials for provider configuration
ephemeral "vault_kv_secret_v2" "gitlab_internal" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}

ephemeral "vault_kv_secret_v2" "gitlab_pat" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/pat"
}
