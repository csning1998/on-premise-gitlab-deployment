
/**
 * Implicit sub-ordering within tier 40:
 * this layer reads keycloak_oidc (40-provision-keycloak-oidc),
 * which must apply first so that Keycloak OIDC client credentials exist before Harbor SSO is configured.
 * Downstream layers that read this layer's outputs (gitlab-frontend, gitlab-runner, harbor-frontend,
 * observability-frontend) therefore have an implicit three-level sequence within tier 40:
 * (1) keycloak-oidc, (2) harbor-bootstrapper-frontend, (3) the above consumers.
 */

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

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-bootstrapper-frontend" })
}

data "terraform_remote_state" "keycloak_oidc" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-keycloak-oidc" })
}

ephemeral "vault_kv_secret_v2" "harbor_bootstrapper" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor-bootstrapper"]["frontend"]
}
