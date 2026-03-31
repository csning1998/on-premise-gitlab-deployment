
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

# Default for Bootstrap, connect to Local Podman Vault
provider "vault" {
  address      = data.terraform_remote_state.vault_bootstrapper.outputs.vault_addr
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_bootstrapper.outputs.role_id
      secret_id = data.terraform_remote_state.vault_bootstrapper.outputs.secret_id
    }
  }
  skip_child_token = true
}
