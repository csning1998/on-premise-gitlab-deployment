data "terraform_remote_state" "topology" {
  backend = "local"
  config = {
    path = "${path.root}/../00-global-topology/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../05-central-lb/terraform.tfstate"
  }
}

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

data "vault_generic_secret" "prod_credential" {
  provider = vault.bootstrapper
  path     = "secret/on-premise-gitlab-deployment/infrastructure"
}

data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}
