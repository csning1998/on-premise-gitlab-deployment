

data "terraform_remote_state" "volume" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/05-foundation-volume" })
}

data "terraform_remote_state" "load_balancer" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/10-shared-load-balancer-frontend" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

data "vault_kv_secret_v2" "guest_vm" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["gitaly"]
}

data "vault_kv_secret_v2" "postgres_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["praefect-patroni"]
}

data "vault_kv_secret_v2" "internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}
