
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "network" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/10-shared-load-balancer-frontend" })
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

data "terraform_remote_state" "postgres" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-postgres" })
}

data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-minio" })
}

data "terraform_remote_state" "redis" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-redis" })
}

ephemeral "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["postgres"]
}

ephemeral "vault_kv_secret_v2" "minio_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["minio"]
}
