
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

# Production Vault Initial Credentials
data "vault_kv_secret_v2" "prod_credential" {
  provider = vault.bootstrapper
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/credentials"
}
