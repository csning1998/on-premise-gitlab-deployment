
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
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

provider "vault" {
  address      = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
  ca_cert_file = abspath("${path.root}/../10-vault-raft/tls/vault-ca.crt")
  token        = jsondecode(file(abspath("${path.root}/../../../ansible/fetched/vault/vault_init_output.json"))).root_token
}

provider "kubernetes" {
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

provider "harbor" {
  url      = "https://${local.harbor_hostname}"
  username = "admin"
  password = local.harbor_admin_password
}
