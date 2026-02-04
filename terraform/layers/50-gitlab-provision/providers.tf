
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

provider "helm" {
  kubernetes = {
    host                   = local.cluster_info.server
    cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate     = base64decode(local.user_info["client-certificate-data"])
    client_key             = base64decode(local.user_info["client-key-data"])
  }
}

provider "postgresql" {
  scheme = "postgres"
  host   = data.terraform_remote_state.gitlab_postgres.outputs.gitlab_postgres_virtual_ip
  port   = data.terraform_remote_state.gitlab_postgres.outputs.gitlab_postgres_haproxy_rw_port

  username = "postgres"
  password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]

  sslmode = "require"

  connect_timeout = 15
}
