
data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../20-vault-pki/terraform.tfstate"
  }
}

data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}
