
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.11.3"
    }
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
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

# Harbor admin uses basic auth on /api/v2.0 and is not subject to OIDC redirect.
provider "harbor" {
  url      = "https://${local.harbor_hostname}"
  username = "admin"
  password = ephemeral.vault_kv_secret_v2.harbor_vars.data["harbor_admin_password"]
}
