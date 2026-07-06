

data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/15-shared-vault-frontend" })
}

data "terraform_remote_state" "postgres" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-postgres" })
}

data "terraform_remote_state" "redis" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-redis" })
}

data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-minio" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["postgres"]
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
