
# Foundation Metadata State (SSoT)
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

# Kubeadm Cluster State
data "terraform_remote_state" "kubeadm" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitaly_praefect" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-gitaly-praefect/terraform.tfstate"
  }
}

data "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["gitaly"]
}

# 0. Infrastructure Provisioning State
data "terraform_remote_state" "provision" {
  backend = "local"
  config = {
    path = "../40-provision-gitlab-frontend/terraform.tfstate"
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
data "vault_kv_secret_v2" "harbor_bootstrapper" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor-bootstrapper"]["frontend"]
}

# 1. Database Provisioning State
data "terraform_remote_state" "provision_databases" {
  backend = "local"
  config = {
    path = "../40-provision-gitlab-databases/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor" {
  backend = "local"
  config = {
    path = "../50-platform-harbor-frontend/terraform.tfstate"
  }
}

# 2. Fetch Kubeconfig from Production Vault
ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/infrastructure/kubeconfig/gitlab"
}

# Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

data "vault_kv_secret_v2" "gitlab_s3" {
  provider = vault.production
  for_each = local.minio_function_map
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/gitlab/app/s3_credentials/${each.value}"
}

# Harbor Bootstrapper Robot Account (RBAC)
ephemeral "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}

# Database Credentials (Redis)
data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["redis"]
}

data "vault_kv_secret_v2" "gitlab_app_database" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/gitlab/app/database"
}

# 3. Keycloak OIDC State & Client Secret
data "terraform_remote_state" "keycloak_oidc" {
  backend = "local"
  config = {
    path = "../40-provision-keycloak-oidc/terraform.tfstate"
  }
}

data "vault_kv_secret_v2" "keycloak_gitlab_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/keycloak/oidc/clients/gitlab_frontend"
}

# GitLab Internal Secrets (Persistent via Layer 30)
data "vault_kv_secret_v2" "gitlab_internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}
