
terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.11.3"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}
