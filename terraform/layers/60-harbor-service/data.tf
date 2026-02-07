
# MicroK8s Cluster State

data "terraform_remote_state" "microk8s_provision" {
  backend = "local"
  config = {
    path = "../30-harbor-microk8s/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_platform" {
  backend = "local"
  config = {
    path = "../40-harbor-platform/terraform.tfstate"
  }
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "../20-vault-pki/terraform.tfstate"
  }
}

# Infrastructure VIPs
data "terraform_remote_state" "redis" {
  backend = "local"
  config = {
    path = "../20-harbor-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../20-harbor-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio" {
  backend = "local"
  config = {
    path = "../20-harbor-minio/terraform.tfstate"
  }
}

data "vault_generic_secret" "variables" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/harbor/databases"
}

data "vault_generic_secret" "harbor_vars" {
  path = "secret/on-premise-gitlab-deployment/harbor/app"
}

data "vault_generic_secret" "s3_credentials" {
  path = "secret/on-premise-gitlab-deployment/harbor/s3_credentials/harbor-registry"
}
