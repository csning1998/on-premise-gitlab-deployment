
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}
