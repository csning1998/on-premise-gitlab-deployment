
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}
