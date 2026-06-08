
# Foundation Metadata State (SSoT)
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

# Infrastructure VIPs
data "terraform_remote_state" "redis" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-redis" })
}

data "terraform_remote_state" "postgres" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-postgres" })
}

data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-minio" })
}

# MicroK8s Cluster State
data "terraform_remote_state" "microk8s_provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-frontend" })
}

# Harbor Bootstrapper State
data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

# Harbor Bootstrapper Admin Credentials (for Helm OCI Registry)
data "vault_kv_secret_v2" "harbor_bootstrapper_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor-bootstrapper"]["frontend"]
}

# 1. Fetch Harbor Secrets from Production Vault
data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["redis"]
}

data "vault_kv_secret_v2" "harbor_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor"]["frontend"]
}

data "vault_kv_secret_v2" "harbor_app_database" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor/app/database"
}

data "vault_kv_secret_v2" "s3_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor/app/s3_credentials/harbor-registry"
}

# Harbor Bootstrapper Robot Account (RBAC)
ephemeral "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}

# 2. Fetch Kubeconfig from Production Vault
ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/infrastructure/kubeconfig/harbor"
}

# Fetch the Cluster CA from the in-cluster ConfigMap
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}
