
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "../15-shared-vault-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "../20-security-vault-approle/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../25-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "keycloak" {
  backend = "local"
  config = {
    path = "../30-infra-keycloak-frontend/terraform.tfstate"
  }
}

ephemeral "vault_kv_secret_v2" "keycloak_admin" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["keycloak"]["frontend"]
}
