
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    kubectl = { # Hack method for ClusterIssuer
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
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
  address      = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  ca_cert_file = abspath("${path.root}/../10-vault-core/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}

provider "kubernetes" {
  host                   = local.cluster_info.server
  cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
  client_certificate     = base64decode(local.user_info["client-certificate-data"])
  client_key             = base64decode(local.user_info["client-key-data"])
}

provider "kubectl" {
  load_config_file       = false
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
