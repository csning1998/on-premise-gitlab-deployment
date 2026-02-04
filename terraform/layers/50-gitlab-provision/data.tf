

# Kubeadm Cluster State

data "terraform_remote_state" "gitlab_cluster" {
  backend = "local"
  config = {
    path = "../30-gitlab-kubeadm/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_platform" {
  backend = "local"
  config = {
    path = "../40-gitlab-platform/terraform.tfstate"
  }
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}

# Infrastructure VIPs
data "terraform_remote_state" "gitlab_redis" {
  backend = "local"
  config = {
    path = "../20-gitlab-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_postgres" {
  backend = "local"
  config = {
    path = "../20-gitlab-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_minio" {
  backend = "local"
  config = {
    path = "../20-gitlab-minio/terraform.tfstate"
  }
}

data "vault_generic_secret" "variables" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}

data "vault_generic_secret" "gitlab_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app"
}

# path: secret/on-premise-gitlab-deployment/gitlab/s3_credentials/[bucket_name]

data "vault_generic_secret" "s3_credentials" {
  for_each = local.s3_bucket_names
  path     = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/${each.key}"
}

data "vault_generic_secret" "s3_artifacts" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-artifacts"
}
