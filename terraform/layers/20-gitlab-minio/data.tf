
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}

# Get MinIO credentials from Vault
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}
