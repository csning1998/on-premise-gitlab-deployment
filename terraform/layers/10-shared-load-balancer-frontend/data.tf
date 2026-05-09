
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_bootstrapper" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-vault-bootstrapper/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../05-foundation-network/terraform.tfstate"
  }
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
