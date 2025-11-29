
# MicroK8s Cluster State
data "terraform_remote_state" "microk8s_provision" {
  backend = "local"
  config = {
    path = "../30-harbor-microk8s/terraform.tfstate"
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

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/databases"
}

data "vault_generic_secret" "harbor_vars" {
  path = "secret/on-premise-gitlab-deployment/harbor"
}
