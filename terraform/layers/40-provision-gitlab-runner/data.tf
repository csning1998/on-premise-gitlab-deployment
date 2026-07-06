

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/20-security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-pki" })
}

data "terraform_remote_state" "runner_cluster" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-runner" })
}

data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/15-shared-vault-frontend" })
}

data "terraform_remote_state" "gitlab_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-frontend" })
}

data "terraform_remote_state" "harbor_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-harbor-frontend" })
}

data "terraform_remote_state" "postgres" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-postgres" })
}

data "terraform_remote_state" "redis" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-redis" })
}

data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-minio" })
}

# Reads a sibling L40 layer instead of an L30 layer. 40-provision-observability-frontend
# must be applied before this layer, since the Mimir FQDN/VIP produced there is consumed
# below for the metrics-ingestion host alias.
data "terraform_remote_state" "observability_provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-observability-frontend" })
}

data "terraform_remote_state" "harbor_bootstrapper_oci" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/infrastructure/kubeconfig/gitlab-runner"
}

data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

ephemeral "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}
