
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../05-foundation-network/terraform.tfstate"
  }
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../20-security-pki/terraform.tfstate"
  }
}

# Infrastructure VIPs
data "terraform_remote_state" "redis" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-minio/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio_provision" {
  backend = "local"
  config = {
    path = "../40-provision-gitlab-minio/terraform.tfstate"
  }
}

# Kubeadm Cluster State
data "terraform_remote_state" "kubeadm" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-kubeadm/terraform.tfstate"
  }
}

data "terraform_remote_state" "platform_gitlab" {
  backend = "local"
  config = {
    path = "../50-platform-gitlab/terraform.tfstate"
  }
}

# Harbor Bootstrapper State
data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "local"
  config = {
    path = "../40-provision-harbor-bootstrapper/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "../16-foundation-vault-production-bootstrap/terraform.tfstate"
  }
}


# 2. Fetch Kubeconfig from Production Vault
data "vault_generic_secret" "kubeconfig" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab"
}

data "vault_generic_secret" "variables" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/guest_vm"
}

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/databases"
}

# path: secret/on-premise-gitlab-deployment/gitlab/s3_credentials/[bucket_name]

data "vault_generic_secret" "s3_credentials" {
  provider = vault.production
  for_each = local.minio_function_map
  path     = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/${each.value}"
}


# Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}
