
data "terraform_remote_state" "topology" {
  backend = "local"
  config = {
    path = "${path.root}/../00-global-topology/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_raft_config" {
  backend = "local"
  config = {
    path = "${path.root}/../10-vault-raft/terraform.tfstate"
  }
}

data "vault_generic_secret" "prod_credential" {
  provider = vault.bootstrapper
  path     = "secret/on-premise-gitlab-deployment/infrastructure"
}
