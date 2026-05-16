
# 1. Global Application Settings (OIDC Behavior)
resource "gitlab_application_settings" "this" {
  signup_enabled                          = false
  password_authentication_enabled_for_web = false

  default_project_visibility = "internal"
  default_group_visibility   = "internal"
}

# 2. Hierarchical Group Structure
#    Top-level Engineering Group
resource "gitlab_group" "engineering" {
  name             = "engineering"
  path             = "engineering"
  description      = "Engineering Organization"
  visibility_level = "internal"
}

#    Subgroups for each development team
resource "gitlab_group" "subgroups" {
  for_each         = local.engineering_groups
  name             = each.value.name
  path             = each.key
  description      = each.value.description
  parent_id        = gitlab_group.engineering.id
  visibility_level = "internal"
}

resource "gitlab_group_membership" "team_memberships" {
  for_each = { for item in local.membership_list : "${item.team}-${item.user}" => item }

  group_id     = gitlab_group.subgroups[each.value.team].id
  user_id      = gitlab_user.oidc_users[each.value.user].id
  access_level = "developer"
}

# 3. Pre-provision GitLab users
resource "gitlab_user" "oidc_users" {
  for_each = local.kc_users

  name     = "${each.value.first_name} ${each.value.last_name}"
  username = each.value.username
  email    = each.value.email

  # Infrastructure team members get admin privileges
  is_admin = contains(each.value.groups, "infra")

  can_create_group = true
  projects_limit   = 100

  # Required by resource but overridden by OIDC identity.
  # Using the initial password from Keycloak for consistency.
  password       = each.value.password
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
