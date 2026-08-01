

data "terraform_remote_state" "volume" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-volume" })
}

data "terraform_remote_state" "load_balancer" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-load-balancer-frontend" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

data "vault_kv_secret_v2" "guest_vm" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "creds" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["minio"]
}

