
terraform {
  required_providers {
    vault = {
      source                = "hashicorp/vault"
      version               = "5.5.0"
      configuration_aliases = [vault.production, vault.bootstrap]
    }
    time = {
      source  = "hashicorp/time"
      version = "0.11.1"
    }
  }
}
