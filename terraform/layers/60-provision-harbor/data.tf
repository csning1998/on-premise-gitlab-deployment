
# 1. Fundamental Infrastructure Metadata
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

# 2. Security & Identity Context
data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../25-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "../20-security-vault-approle/terraform.tfstate"
  }
}

# 3. Dependency Service States
data "terraform_remote_state" "infra_redis" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "infra_postgres" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "infra_minio" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-minio/terraform.tfstate"
  }
}

# 4. Cluster Discovery (L30)
data "terraform_remote_state" "microk8s_infra" {
  backend = "local"
  config = {
    path = "../30-infra-harbor-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_platform" {
  backend = "local"
  config = {
    path = "../50-platform-harbor/terraform.tfstate"
  }
}

# 5. Secret Retrieval via Vault (PRODUCTION ALIAS)
# Kubeconfig for Harbor Cluster (Uploaded during L30)
data "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/infrastructure/kubeconfig/harbor"
}

# Shared Variables & Service Credentials
data "vault_kv_secret_v2" "variables" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "harbor_db" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/databases"
}

data "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/app"
}

data "vault_kv_secret_v2" "harbor_s3" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/s3_credentials/harbor-registry"
}
