
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-vault-approle/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../25-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_frontend" {
  backend = "local"
  config = {
    path = "${path.root}/../30-infra-gitlab-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "runner_cluster" {
  backend = "local"
  config = {
    path = "${path.root}/../30-infra-gitlab-runner/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "local"
  config = {
    path = "${path.root}/../30-infra-harbor-bootstrapper-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "harbor_bootstrapper_oci" {
  backend = "local"
  config = {
    path = "${path.root}/../40-provision-harbor-bootstrapper-frontend/terraform.tfstate"
  }
}

data "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/infrastructure/kubeconfig/gitlab-runner"
}

data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "default"
  }
}

# 11. Namespace Management
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = var.gitlab_runner_config.namespace
  }
}
