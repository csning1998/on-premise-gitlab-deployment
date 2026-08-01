
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-metadata" })
}

data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-vault-bootstrapper" })
}

data "terraform_remote_state" "volume" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-volume" })
}

data "terraform_remote_state" "load_balancer" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-load-balancer-frontend" })
}

data "vault_kv_secret_v2" "guest_vm" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/guest_vm"
}
