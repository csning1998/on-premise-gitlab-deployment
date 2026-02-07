
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}

data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/harbor/databases"
}
