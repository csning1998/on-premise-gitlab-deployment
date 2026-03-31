
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

data "terraform_remote_state" "volume" {
  backend = "local"
  config = {
    path = "${path.root}/../05-foundation-volume/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../10-shared-load-balancer/terraform.tfstate"
  }
}

data "vault_kv_secret_v2" "guest_vm" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "infrastructure" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/infrastructure"
}

data "vault_kv_secret_v2" "credentials" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/credentials"
}
