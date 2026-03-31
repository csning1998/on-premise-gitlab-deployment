
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
      version = "5.5.0"
    }
  }
}

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
  ca_cert_file = local.state.vault_pki.bootstrap_ca.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}

# Configure the Kubernetes provider using details from the remote state
provider "kubernetes" {
  host                   = local.api_server_connection.host
  cluster_ca_certificate = local.api_server_connection.ca_cert
  client_certificate     = local.api_server_connection.client_certificate
  client_key             = local.api_server_connection.client_key
}

provider "kubectl" {
  load_config_file       = false
  host                   = local.api_server_connection.host
  cluster_ca_certificate = local.api_server_connection.ca_cert
  client_certificate     = local.api_server_connection.client_certificate
  client_key             = local.api_server_connection.client_key
}

provider "helm" {
  kubernetes = {
    host                   = local.api_server_connection.host
    cluster_ca_certificate = local.api_server_connection.ca_cert
    client_certificate     = local.api_server_connection.client_certificate
    client_key             = local.api_server_connection.client_key
  }
}
