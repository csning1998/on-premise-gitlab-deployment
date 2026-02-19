
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

# Bootstrap Provider (Podman Vault)
provider "vault" {
  alias           = "bootstrapper"
  address         = var.vault_dev_addr
  token           = trimspace(file(abspath("${path.root}/../../../vault/keys/root-token.txt")))
  skip_tls_verify = true
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  address      = "https://${data.terraform_remote_state.vault_raft_config.outputs.service_vip}:443"
  token        = data.vault_generic_secret.prod_credential.data["prod_vault_root_token"]
  ca_cert_file = local_file.bootstrap_ca.filename
}
