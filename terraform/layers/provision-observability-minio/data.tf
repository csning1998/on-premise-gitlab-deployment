
data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-vault-frontend" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

# HashiCorp Vault PKI State
data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

# Observability MinIO Infrastructure State
data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-observability-minio" })
}

# MinIO Root Credentials
ephemeral "vault_kv_secret_v2" "minio_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["observability"]["minio"]
}
