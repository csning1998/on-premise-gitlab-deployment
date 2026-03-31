
data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../16-foundation-vault-production-bootstrap/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio_infra" {
  backend = "local"
  config = {
    path = "${path.module}/../30-infra-harbor-minio/terraform.tfstate"
  }
}


data "vault_generic_secret" "db_vars" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/harbor/databases"
}
