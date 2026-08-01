

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-vault-approle" })
}

data "terraform_remote_state" "vault_pki" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/security-pki" })
}

data "terraform_remote_state" "runner_cluster" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-gitlab-runner" })
}

data "terraform_remote_state" "vault_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/shared-vault-frontend" })
}

data "terraform_remote_state" "gitlab_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-gitlab-frontend" })
}

data "terraform_remote_state" "harbor_frontend" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-harbor-frontend" })
}

data "terraform_remote_state" "postgres" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-gitlab-postgres" })
}

data "terraform_remote_state" "redis" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-gitlab-redis" })
}

data "terraform_remote_state" "minio" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-gitlab-minio" })
}

data "terraform_remote_state" "observability_infra" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/infra-observability-frontend" })
}

data "terraform_remote_state" "harbor_bootstrapper_oci" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/provision-harbor-bootstrapper-frontend" })
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
