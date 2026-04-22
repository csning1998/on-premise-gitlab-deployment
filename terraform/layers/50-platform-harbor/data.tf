
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

# Harbor Bootstrapper Admin Credentials (for Helm OCI Registry)
data "vault_kv_secret_v2" "harbor_bootstrapper_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor-bootstrapper/app"
}

# 1. Fetch Harbor Secrets from Production Vault
data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/databases"
}

data "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/app"
}

data "vault_kv_secret_v2" "s3_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/s3_credentials/harbor-registry"
}

# Harbor Bootstrapper Robot Account (RBAC)
data "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor-bootstrapper/robot"
}

# 2. Fetch Kubeconfig from Production Vault
data "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor"
}

# 3. Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}
