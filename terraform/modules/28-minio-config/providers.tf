
terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.12.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}
