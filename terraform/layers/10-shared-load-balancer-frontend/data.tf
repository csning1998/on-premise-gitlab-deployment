
data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-vault-bootstrapper" })
}

data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "network" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/05-foundation-network" })
}

data "vault_generic_secret" "guest_vm" {
  path = "secret/on-premise-gitlab-deployment/guest_vm"
}

data "vault_generic_secret" "infrastructure" {
  path = "secret/on-premise-gitlab-deployment/infrastructure"
}

data "vault_generic_secret" "credentials" {
  path = "secret/on-premise-gitlab-deployment/credentials"
}
