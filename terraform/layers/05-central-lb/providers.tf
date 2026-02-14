
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
  address      = var.vault_dev_addr
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")
}

data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "infra_vars" {
  path = "secret/on-premise-gitlab-deployment/infrastructure"
}
