
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-vault-bootstrapper" })
}

data "terraform_remote_state" "volume" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/05-foundation-volume" })
}

data "terraform_remote_state" "load_balancer" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/10-shared-load-balancer-frontend" })
}

data "vault_generic_secret" "guest_vm" {
  path = "secret/on-premise-gitlab-deployment/guest_vm"
}
