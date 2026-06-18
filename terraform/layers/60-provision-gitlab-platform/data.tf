
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

# Fetch GitLab Admin/Root credentials for provider configuration
ephemeral "vault_kv_secret_v2" "gitlab_internal" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}

ephemeral "vault_kv_secret_v2" "gitlab_pat" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/gitlab/app/pat"
}
