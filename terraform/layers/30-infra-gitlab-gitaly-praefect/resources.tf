
resource "vault_approle_auth_backend_role_secret_id" "component_agents" {
  for_each = var.target_clusters
  provider = vault.production

  backend   = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[data.terraform_remote_state.metadata.outputs.global_pki_map[module.context.components_context[each.key].pki_key].key].auth_path
  role_name = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[data.terraform_remote_state.metadata.outputs.global_pki_map[module.context.components_context[each.key].pki_key].key].role_name

  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-gitaly-praefect"
    "component" = each.key
  })
}

resource "random_password" "gitaly_token" {
  length  = 32
  special = false
}

resource "random_password" "praefect_external_token" {
  count   = contains(keys(var.target_clusters), "praefect") ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "praefect_db_password" {
  count   = contains(keys(var.target_clusters), "praefect") ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "gitlab_shell_secret" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/gitaly"

  data_json = jsonencode({
    gitaly_token            = random_password.gitaly_token.result
    gitlab_shell_secret     = random_password.gitlab_shell_secret.result
    praefect_external_token = one(random_password.praefect_external_token[*].result)
    praefect_db_password    = one(random_password.praefect_db_password[*].result)
  })
}

resource "random_password" "pg_replication_password" {
  length  = 32
  special = false
}

resource "random_password" "pg_superuser_password" {
  length  = 32
  special = false
}

resource "random_password" "pg_vrrp_secret" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "postgres_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/postgres"

  data_json = jsonencode({
    pg_replication_password = random_password.pg_replication_password.result
    pg_superuser_password   = random_password.pg_superuser_password.result
    pg_vrrp_secret          = random_password.pg_vrrp_secret.result
  })
}

resource "random_password" "rails_secret" {
  length  = 32
  special = false
}

resource "random_password" "root_password" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "gitlab_internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key = random_password.rails_secret.result
    root_password    = random_password.root_password.result
  })
}
