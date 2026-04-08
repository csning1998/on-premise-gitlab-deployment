
# Foundation Metadata State (SSoT)
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "../20-security-vault-approle/terraform.tfstate"
  }
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../25-security-pki/terraform.tfstate"
  }
}

# Infrastructure VIPs
data "terraform_remote_state" "redis" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-minio/terraform.tfstate"
  }
}

# MicroK8s Cluster State
data "terraform_remote_state" "microk8s_provision" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-frontend/terraform.tfstate"
  }
}

# Harbor Bootstrapper State
data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "local"
  config = {
    path = "../40-provision-harbor-bootstrapper-frontend/terraform.tfstate"
  }
}

# 1. Fetch Harbor Secrets from Production Vault
data "vault_generic_secret" "db_vars" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/harbor/databases"
}

data "vault_generic_secret" "harbor_vars" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/harbor/app"
}

# 2. Fetch Kubeconfig from Production Vault
data "vault_generic_secret" "kubeconfig" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor"
}

# 3. Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}
