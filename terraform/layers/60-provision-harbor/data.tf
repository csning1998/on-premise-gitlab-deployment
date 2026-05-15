
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "../00-foundation-metadata/terraform.tfstate"
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

data "terraform_remote_state" "keycloak_oidc" {
  backend = "local"
  config = {
    path = "../40-provision-keycloak-oidc/terraform.tfstate"
  }
}

data "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/app"
}

data "vault_kv_secret_v2" "keycloak_harbor_client" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/oidc/clients/harbor"
}
