
data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../10-vault-raft/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../20-vault-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_core" {
  backend = "local"
  config = {
    path = "${path.root}/../30-dev-harbor-core/terraform.tfstate"
  }
}

data "vault_generic_secret" "prod_credential" {
  provider = vault.bootstrapper
  path     = "secret/on-premise-gitlab-deployment/infrastructure"
}

data "vault_generic_secret" "dev_harbor_app" {
  path = "secret/on-premise-gitlab-deployment/dev-harbor/app"
}
