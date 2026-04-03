
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

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "../16-security-vault-approle/terraform.tfstate"
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

data "terraform_remote_state" "provision_databases" {
  backend = "local"
  config = {
    path = "../40-provision-gitlab-databases/terraform.tfstate"
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

# 2. Fetch Kubeconfig from Production Vault
data "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab"
}

data "vault_kv_secret_v2" "variables" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}

# Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

data "vault_kv_secret_v2" "gitlab_db" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/database"
}

data "vault_kv_secret_v2" "gitlab_redis" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/redis"
}

data "vault_kv_secret_v2" "gitlab_s3" {
  provider = vault.production
  for_each = local.minio_function_map
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/s3_credentials/${each.value}"
}

data "vault_kv_secret_v2" "gitlab_internal" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/internal"
}
