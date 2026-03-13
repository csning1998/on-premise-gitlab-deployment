
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
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.25.0"
    }
    # gitlab = {
    #   source  = "gitlabhq/gitlab"
    #   version = "17.8.0"
    # }
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

provider "postgresql" {
  scheme   = "postgres"
  host     = local.postgres_vip
  port     = local.postgres_rw_port
  username = "postgres"
  password = local.postgres_password

  sslmode         = "require"
  connect_timeout = 15
}
