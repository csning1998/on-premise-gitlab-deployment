
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

# Fetch GitLab Admin/Root credentials for provider configuration
ephemeral "vault_kv_secret_v2" "gitlab_internal" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}

ephemeral "vault_kv_secret_v2" "gitlab_pat" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/gitlab/app/pat"
}
