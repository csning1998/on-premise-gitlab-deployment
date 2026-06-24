
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
data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-observability-minio" })
}

# MicroK8s Cluster State
data "terraform_remote_state" "microk8s_provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-observability-frontend" })
}

# Harbor Bootstrapper State (OCI chart proxy and registry redirection)
data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

# MinIO Bucket Provisioning State (SSoT for bucket names)
data "terraform_remote_state" "minio_provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-observability-minio" })
}

# Harbor Bootstrapper Robot Account (for Helm OCI Registry auth)
ephemeral "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}

# Observability Cluster Kubeconfig
ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/infrastructure/kubeconfig/observability"
}

# MinIO Root Credentials (Loki only; tracked for migration to per-bucket in follow-up issue)
data "vault_kv_secret_v2" "minio_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["observability"]["minio"]
}

# Grafana Admin Credentials
data "vault_kv_secret_v2" "grafana_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["observability"]["frontend"]
}

# Mimir Per-Bucket S3 Credentials (provisioned by 40-provision-observability-minio)
data "vault_kv_secret_v2" "mimir_blocks_creds" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/observability/app/s3_credentials/mimir-blocks"
}

data "vault_kv_secret_v2" "mimir_ruler_creds" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/observability/app/s3_credentials/mimir-ruler"
}

data "vault_kv_secret_v2" "mimir_alertmanager_creds" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/observability/app/s3_credentials/mimir-alertmanager"
}

# CoreDNS ClusterIP (used as nginx resolver in Mimir and Loki gateway)
data "kubernetes_service" "kube_dns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}

# Fetch the Cluster CA from the in-cluster ConfigMap
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}
