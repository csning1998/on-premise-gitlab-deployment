
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

data "terraform_remote_state" "keycloak_provisioning" {
  backend = "local"
  config = {
    path = "../40-provision-keycloak-oidc/terraform.tfstate"
  }
}

# Read OIDC Client credentials from Vault (Created in L40)
data "vault_kv_secret_v2" "keycloak_vault_client" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/oidc/clients/vault_frontend"
}
