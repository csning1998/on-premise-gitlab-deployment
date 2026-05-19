
# Call the Identity Module to generate AppRole & Secret ID for each component
resource "vault_approle_auth_backend_role_secret_id" "component_agents" {
  for_each = var.target_clusters
  provider = vault.production

  backend   = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[local.components_context[each.key].pki_key].key].auth_path
  role_name = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[local.components_context[each.key].pki_key].key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-gitaly-praefect"
    "component" = each.key
  })
}

# Dynamic Gitaly Auth Token Generation
resource "random_password" "gitaly_token" {
  length  = 32
  special = false
}

# Dynamic Praefect External Token Generation
resource "random_password" "praefect_external_token" {
  length  = 32
  special = false
}

# Dynamic Praefect DB Password Generation
resource "random_password" "praefect_db_password" {
  length  = 32
  special = false
}

# Dynamic GitLab Shell Secret Generation
resource "random_password" "gitlab_shell_secret" {
  length  = 32
  special = false
}

# Upload dynamically generated Gitaly Token to isolated Vault space
resource "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/gitaly"

  data_json = jsonencode({
    gitaly_token            = random_password.gitaly_token.result
    praefect_external_token = random_password.praefect_external_token.result
    praefect_db_password    = random_password.praefect_db_password.result
    gitlab_shell_secret     = random_password.gitlab_shell_secret.result
  })
}

# Dynamic GitLab Rails Encryption Key Generation
resource "random_password" "rails_secret" {
  length  = 32
  special = false
}

# Dynamic GitLab Initial Root Password Generation
resource "random_password" "root_password" {
  length  = 32
  special = false
}

# Upload dynamically generated Internal Secrets to isolated Vault space
resource "vault_kv_secret_v2" "gitlab_internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key = random_password.rails_secret.result
    root_password    = random_password.root_password.result
  })
}

