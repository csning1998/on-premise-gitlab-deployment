
data "terraform_remote_state" "topology" {
  backend = "local"
  config = {
    path = "${path.module}/../00-global-topology/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_raft_config" {
  backend = "local"
  config = {
    path = "../10-vault-raft/terraform.tfstate"
  }
}
