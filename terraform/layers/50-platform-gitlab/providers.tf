
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

provider "vault" {
  alias        = "bootstrapper"
  address      = var.vault_dev_addr
  token        = trimspace(file(abspath("${path.root}/../../../vault/keys/root-token.txt")))
  ca_cert_file = abspath("${path.root}/../../../vault/tls/ca.pem")
}

provider "vault" {
  alias        = "production"
  address      = local.vault_address
  ca_cert_file = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca.path
  token        = data.vault_generic_secret.prod_credential.data["prod_vault_root_token"]
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
