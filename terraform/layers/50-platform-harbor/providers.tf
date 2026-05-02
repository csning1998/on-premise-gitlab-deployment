
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

# Production Provider (Layer 10 Vault)
provider "vault" {
  alias        = "production"
  address      = local.vault_address
  ca_cert_file = local.state.vault_pki.bootstrap_ca_b64.path

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.state.vault_prod_bootstrap.production_role_id
      secret_id = local.state.vault_prod_bootstrap.production_secret_id
    }
  }
  skip_child_token = true
}

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

  registries = [
    {
      url      = "oci://${local.harbor_registry}"
      username = data.vault_kv_secret_v2.harbor_bootstrapper_robot.data["username_puller"]
      password = data.vault_kv_secret_v2.harbor_bootstrapper_robot.data["password_puller"]
    }
  ]
}

provider "harbor" {
  url      = "https://${local.harbor_fqdn}"
  username = "admin"
  password = local.harbor_admin_password
}
