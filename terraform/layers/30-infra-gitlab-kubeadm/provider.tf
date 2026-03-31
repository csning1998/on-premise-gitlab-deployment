
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.sys_vault_addr
  ca_cert_file = local.state.vault_sys.ca_cert_path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
      secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
    }
  }
  skip_child_token = true
}
