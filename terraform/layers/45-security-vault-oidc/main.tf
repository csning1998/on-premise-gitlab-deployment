
# 1. Enable OIDC Auth Backend
resource "vault_jwt_auth_backend" "keycloak" {
  provider              = vault.production
  description           = "OIDC Auth Backend for Keycloak"
  path                  = "oidc"
  type                  = "oidc"
  oidc_discovery_url    = local.oidc_discovery_url
  oidc_discovery_ca_pem = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  oidc_client_id        = local.oidc_client_id
  oidc_client_secret    = local.oidc_client_secret

  tune {
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "24h"
  }
}

# 2. Configure Unified OIDC Role
# This role allows everyone from Keycloak to authenticate; actual permissions
# are managed via Identity Group mappings based on the 'groups' claim.
resource "vault_jwt_auth_backend_role" "keycloak_user" {
  provider             = vault.production
  backend              = vault_jwt_auth_backend.keycloak.path
  role_name            = "keycloak-user"
  token_policies       = ["default"]
  user_claim           = "preferred_username"
  groups_claim         = "groups"
  role_type            = "oidc"
  verbose_oidc_logging = true

  allowed_redirect_uris = local.state.keycloak_oidc.vault_redirect_uris
}

# 3. Identity Groups (External) - Dynamic Mapping for all Management Roles
resource "vault_identity_group" "management_groups" {
  provider = vault.production
  for_each = local.state.vault_pki.management_policies

  name     = "keycloak-${replace(each.key, "oidc-", "")}s" # e.g. keycloak-admins, keycloak-auditors
  type     = "external"
  policies = [each.value]

  metadata = {
    source = "keycloak"
  }
}

# 4. Group Aliases - Linking Keycloak groups to Vault groups
resource "vault_identity_group_alias" "management_group_aliases" {
  provider = vault.production
  for_each = local.state.vault_pki.management_policies

  # Keycloak group name (Assuming groups in Keycloak are named 'admin', 'auditor', 'developer')
  name           = replace(each.key, "oidc-", "")
  mount_accessor = vault_jwt_auth_backend.keycloak.accessor
  canonical_id   = vault_identity_group.management_groups[each.key].id
}
