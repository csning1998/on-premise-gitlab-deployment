
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
  }
}

provider "vault" {
  address      = local.vault_address
  ca_cert_file = abspath("${path.root}/../10-vault-raft/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}

# Configure the Kubernetes provider using details from the remote state
provider "kubernetes" {
  host                   = local.k8s_provider_auth.host
  cluster_ca_certificate = local.k8s_provider_auth.cluster_ca_certificate
  client_certificate     = local.k8s_provider_auth.client_certificate
  client_key             = local.k8s_provider_auth.client_key
}

provider "kubectl" {
  load_config_file       = false
  host                   = local.k8s_provider_auth.host
  cluster_ca_certificate = local.k8s_provider_auth.cluster_ca_certificate
  client_certificate     = local.k8s_provider_auth.client_certificate
  client_key             = local.k8s_provider_auth.client_key
}

provider "helm" {
  kubernetes = {
    host                   = local.k8s_provider_auth.host
    cluster_ca_certificate = local.k8s_provider_auth.cluster_ca_certificate
    client_certificate     = local.k8s_provider_auth.client_certificate
    client_key             = local.k8s_provider_auth.client_key
  }
}
