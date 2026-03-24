
data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "local"
  config = {
    path = "${path.root}/../30-infra-harbor-bootstrapper/terraform.tfstate"
  }
}

data "vault_generic_secret" "prod_credential" {
  provider = vault.bootstrapper
  path     = "secret/on-premise-gitlab-deployment/infrastructure"
}

data "vault_generic_secret" "harbor_bootstrapper" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/harbor-bootstrapper/app"
}
