
data "terraform_remote_state" "vault_raft_config" {
  backend = "local"
  config = {
    path = "../10-vault-raft/terraform.tfstate"
  }
}
