
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}

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

data "terraform_remote_state" "network" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/10-shared-load-balancer-frontend" })
}

data "terraform_remote_state" "observability_infra" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-observability-frontend" })
}

data "terraform_remote_state" "harbor_bootstrapper_oci" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/infrastructure/kubeconfig/gitlab-runner"
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
  name     = "${data.terraform_remote_state.metadata.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}
