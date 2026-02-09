

# Kubeadm Cluster State

data "terraform_remote_state" "kubeadm_provision" {
  backend = "local"
  config = {
    path = "../40-gitlab-kubeadm/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_platform" {
  backend = "local"
  config = {
    path = "../50-gitlab-platform/terraform.tfstate"
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
    path = "../30-gitlab-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../30-gitlab-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio" {
  backend = "local"
  config = {
    path = "../30-gitlab-minio/terraform.tfstate"
  }
}

data "vault_generic_secret" "variables" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}

# path: secret/on-premise-gitlab-deployment/gitlab/s3_credentials/[bucket_name]

data "vault_generic_secret" "s3_credentials" {
  for_each = local.minio_function_map
  path     = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/${each.value}"
}

# Get PKI CA from Vault
data "http" "vault_pki_ca" {
  url         = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443/v1/pki/prod/ca/pem"
  ca_cert_pem = data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert
}
