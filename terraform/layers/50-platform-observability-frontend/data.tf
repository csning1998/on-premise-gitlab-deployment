
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

data "terraform_remote_state" "provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-observability-frontend" })
}

data "terraform_remote_state" "gitlab_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/50-platform-gitlab-frontend" })
}

data "terraform_remote_state" "harbor_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/50-platform-harbor-frontend" })
}

# CoreDNS ClusterIP (used as nginx resolver in Mimir and Loki gateway)
data "kubernetes_service" "kube_dns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}
