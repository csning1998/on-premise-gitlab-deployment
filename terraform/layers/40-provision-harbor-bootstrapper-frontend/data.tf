
data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-vault-approle/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../25-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "local"
  config = {
    path = "${path.root}/../30-infra-harbor-bootstrapper-frontend/terraform.tfstate"
  }
}

ephemeral "vault_kv_secret_v2" "harbor_bootstrapper" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor-bootstrapper/app"
}

ephemeral "vault_kv_secret_v2" "guest_vm" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}
