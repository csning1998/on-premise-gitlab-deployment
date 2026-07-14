
terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.12.0"
    }
    vault = {
      source                = "hashicorp/vault"
      version               = "5.5.0"
      configuration_aliases = [vault.production]
    }
    external = {
      source  = "hashicorp/external"
      version = "2.4.0"
    }
  }
}
