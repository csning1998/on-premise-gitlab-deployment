terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

provider "vault" {
  address      = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  ca_cert_file = abspath("${path.root}/../10-vault-core/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}
