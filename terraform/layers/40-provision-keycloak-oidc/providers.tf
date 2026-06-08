
terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.7.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
  backend "http" {}
}

provider "vault" {
  alias        = "production"
  address      = local.vault_frontend_url
  ca_cert_file = local.state.vault_pki.bootstrap_ca_b64.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}

provider "keycloak" {
  client_id           = "admin-cli"
  username            = local.keycloak_admin_user
  password            = local.keycloak_admin_password
  url                 = local.keycloak_frontend_url
  root_ca_certificate = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  initial_login       = false
}
