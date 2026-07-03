
data "terraform_remote_state" "network" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/10-shared-load-balancer-frontend" })
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

data "terraform_remote_state" "credentials" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/25-security-credentials" })
}

data "terraform_remote_state" "gitaly_praefect" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/30-infra-gitlab-gitaly-praefect" })
}

data "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["gitaly"]
}

# 0. Infrastructure Provisioning State
data "terraform_remote_state" "provision" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-gitlab-frontend" })
}

# Harbor Bootstrapper State
data "terraform_remote_state" "harbor_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-harbor-bootstrapper-frontend" })
}

# Harbor Bootstrapper Admin Credentials (for Helm OCI Registry)
data "vault_kv_secret_v2" "harbor_bootstrapper" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["harbor-bootstrapper"]["frontend"]
}

# 1. Database Provisioning State
data "terraform_remote_state" "provision_databases" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-gitlab-databases" })
}


# 2. Fetch Kubeconfig from Production Vault
ephemeral "vault_kv_secret_v2" "kubeconfig" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/infrastructure/kubeconfig/gitlab"
}

# Fetch the Cluster CA
data "kubernetes_config_map" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

data "vault_kv_secret_v2" "gitlab_s3" {
  provider = vault.production
  for_each = local.minio_function_map
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/s3_credentials/${each.value}"
}

# Harbor Bootstrapper Robot Account (RBAC)
ephemeral "vault_kv_secret_v2" "harbor_bootstrapper_robot" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
}

# Database Credentials (Redis)
data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["redis"]
}

data "vault_kv_secret_v2" "gitlab_app_database" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/database"
}

# 3. Keycloak OIDC State & Client Secret
data "terraform_remote_state" "keycloak_oidc" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/40-provision-keycloak-oidc" })
}

data "vault_kv_secret_v2" "keycloak_gitlab_client" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/keycloak/oidc/clients/gitlab_frontend"
}

# GitLab Internal Secrets (Persistent via Layer 30)
data "vault_kv_secret_v2" "gitlab_internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}
