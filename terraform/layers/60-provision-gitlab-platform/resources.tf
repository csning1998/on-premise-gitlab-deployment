
# 1. Global Application Settings (OIDC Behavior)
resource "gitlab_application_settings" "this" {
  signup_enabled                          = false
  password_authentication_enabled_for_web = true

  default_project_visibility = "internal"
  default_group_visibility   = "internal"

  # Enable shared (instance) runners for all new projects by default.
  # Projects created via push-to-create inherit this setting automatically.
  shared_runners_enabled = true
  shared_runners_text    = "Kubernetes-based shared runners managed by Terraform"
}

# 2. Hierarchical Group Structure
#    Top-level Organization Group
resource "gitlab_group" "top_org" {
  name             = local.target_org_metadata.name
  path             = local.target_org_metadata.name
  description      = local.target_org_metadata.description
  visibility_level = "internal"

  # Allow all projects and subgroups to use instance runners.
  shared_runners_setting = "enabled"
}

#    Subgroups for each development team
resource "gitlab_group" "subgroups" {
  for_each         = local.target_subgroups
  name             = each.value.name
  path             = each.key
  description      = each.value.description
  parent_id        = gitlab_group.top_org.id
  visibility_level = "internal"

  # Inherit instance runner access from the top-level group.
  shared_runners_setting = "enabled"
}

resource "gitlab_group_membership" "team_memberships" {
  for_each = { for item in local.membership_list : "${item.team}-${item.user}" => item }

  group_id     = gitlab_group.subgroups[each.value.team].id
  user_id      = gitlab_user.oidc_users[each.value.user].id
  access_level = "developer"
}

# 3. Random placeholders for local passwords (OIDC is primary)
resource "random_password" "gitlab_user_passwords" {
  for_each = local.kc_users
  length   = 32
  special  = true
  upper    = true
  lower    = true
  numeric  = true
}

# 4. Pre-provision GitLab users
resource "gitlab_user" "oidc_users" {
  for_each = local.kc_users

  name     = "${each.value.first_name} ${each.value.last_name}"
  username = each.value.username
  email    = each.value.email

  # Driven by Keycloak group attributes: Administrators get admin privileges in GitLab
  is_admin = contains(local.admin_users, each.key)

  can_create_group = true
  projects_limit   = 100

  # Decoupled from Keycloak: Use a one-time random password for the shadow account
  password       = random_password.gitlab_user_passwords[each.key].result
  reset_password = false

  lifecycle {
    ignore_changes = [password]
  }
}

# 4. Link GitLab users to Keycloak OIDC identity
resource "gitlab_user_identity" "oidc_links" {
  for_each = local.kc_users

  user_id           = gitlab_user.oidc_users[each.key].id
  external_provider = "openid_connect"
  external_uid      = each.value.id # Using the actual Keycloak UUID for sub claim matching
}

# 5. Pre-create GitLab Runner Entity (GitLab 18+ Architecture alignment)
resource "gitlab_user_runner" "kubernetes_runner" {
  runner_type = "instance_type"
  description = "Production Kubernetes Runner Cluster managed by Terraform"
  tag_list    = ["k8s", "kubernetes", "docker"]
  untagged    = false
}

# 6. Securely Store Runner Authentication Token in Vault
resource "vault_kv_secret_v2" "gitlab_runner_token" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/runner/kubernetes"

  data_json = jsonencode({
    token = gitlab_user_runner.kubernetes_runner.token
  })
}

