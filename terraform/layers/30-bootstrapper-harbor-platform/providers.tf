
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.1"
    }
  }
}


# Bootstrap Provider (Podman Vault)
provider "vault" {
  alias        = "bootstrapper"
  address      = var.vault_dev_addr
  token        = trimspace(file(abspath("${path.root}/../../../vault/keys/root-token.txt")))
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  address      = local.sys_vault_addr
  token        = data.vault_generic_secret.prod_credential.data["prod_vault_root_token"]
  ca_cert_file = local.state.vault_pki.bootstrap_ca_path
}

provider "harbor" {
  url      = "https://${data.terraform_remote_state.harbor_core.outputs.service_vip}"
  username = "admin"
  password = data.vault_generic_secret.dev_harbor_app.data["dev_harbor_admin_password"]
}
