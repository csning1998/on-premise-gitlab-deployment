
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.11.3"
    }
  }
}

provider "vault" {
  # Vault Address is read from VAULT_ADDR env var
}

locals {
  kubeconfig_raw = data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user
}

provider "kubernetes" {
  host                   = local.cluster_info.server
  cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
  client_certificate     = base64decode(local.user_info["client-certificate-data"])
  client_key             = base64decode(local.user_info["client-key-data"])
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster_info.server
    cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate     = base64decode(local.user_info["client-certificate-data"])
    client_key             = base64decode(local.user_info["client-key-data"])
  }
}

provider "harbor" {
  url      = "https://${var.harbor_hostname}"
  username = "admin"
  password = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]
}
