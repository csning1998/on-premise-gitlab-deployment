
module "harbor_system_config" {
  source = "../../modules/configuration/harbor-system-config"

  providers = {
    vault = vault.production
  }
}

# 1. Harbor OIDC Authentication Configuration
resource "harbor_config_auth" "main" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Keycloak"
  oidc_endpoint      = local.oidc_discovery_url
  oidc_client_id     = local.oidc_client_id
  oidc_client_secret = local.oidc_client_secret
  oidc_scope         = "openid,profile,email"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"

  # Map the Keycloak 'admin' group to Harbor System Administrator
  oidc_admin_group = "admin"
}

# 2. External OIDC Groups (Dynamic Mapping from L25 Management Roles)
# This creates the group identities in Harbor that can be assigned to projects.
resource "harbor_group" "oidc_groups" {
  for_each = local.state.vault_pki.management_policies

  group_name = replace(each.key, "oidc-", "") # e.g. admin, auditor, developer
  group_type = 3                              # 3 = OIDC Group
}
