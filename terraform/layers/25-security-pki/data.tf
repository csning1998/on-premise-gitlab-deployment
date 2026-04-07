
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

data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../16-security-vault-approle/terraform.tfstate"
  }
}
