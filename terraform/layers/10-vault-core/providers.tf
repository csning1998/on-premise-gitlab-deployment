
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
}

# Provider A: Default for Bootstrap, connect to Local Podman Vault
provider "vault" {
  address      = var.vault_dev_addr
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")
}

# Provider B: Aliased for Target, connect to new Production Vault
provider "vault" {
  alias = "target_cluster"

  address      = "https://${var.vault_compute.haproxy_config.virtual_ip}:443"
  ca_cert_file = "${path.root}/tls/vault-ca.crt"
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}
