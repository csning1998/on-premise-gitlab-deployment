
# 1. Realm Configuration
resource "keycloak_realm" "infra_realm" {
  realm             = local.realm_id
  enabled           = true
  display_name      = "Infrastructure Centralized Identity"
  display_name_html = "<b>Infrastructure Centralized Identity</b>"

  login_with_email_allowed = true
  reset_password_allowed   = true
  remember_me              = true

  internationalization {
    supported_locales = ["en", "zh-CN"]
    default_locale    = "en"
  }
}

# 2. Client Secret Generation
resource "random_password" "client_secrets" {
  for_each = toset(["vault", "gitlab", "harbor", "minio"])
  length   = 32
  special  = false
}

# 3. OIDC Clients
resource "keycloak_openid_client" "clients" {
  for_each = {
    vault = {
      client_id = "vault-infra"
      name      = "Vault Infrastructure"
      valid_redirect_uris = [
        "https://vault.production.iac.internal/ui/vault/auth/oidc/oidc/callback",
        "https://vault.production.iac.internal/ui/vault/auth/oidc/callback",
        "https://vault.production.iac.internal/vault/oidc/callback",
        "http://localhost:8250/oidc/callback"
      ]
    }
    gitlab = {
      client_id           = "gitlab-infra"
      name                = "GitLab Platform"
      valid_redirect_uris = ["https://gitlab.production.iac.internal/users/auth/openid_connect/callback"]
    }
    harbor = {
      client_id           = "harbor-infra"
      name                = "Harbor Registry"
      valid_redirect_uris = ["https://harbor.production.iac.internal/c/oidc/callback"]
    }
    minio = {
      client_id           = "minio-infra"
      name                = "MinIO Console"
      valid_redirect_uris = ["https://minio.gitlab.production.iac.internal/oauth_callback"]
    }
  }

  realm_id              = keycloak_realm.infra_realm.id
  client_id             = each.value.client_id
  name                  = each.value.name
  enabled               = true
  access_type           = "CONFIDENTIAL"
  client_secret         = random_password.client_secrets[each.key].result
  standard_flow_enabled = true

  valid_redirect_uris = each.value.valid_redirect_uris
  web_origins         = ["+"]
}

# 4. Protocol Mappers (Inject Groups into Token)
resource "keycloak_openid_group_membership_protocol_mapper" "group_mapper" {
  for_each            = keycloak_openid_client.clients
  realm_id            = keycloak_realm.infra_realm.id
  client_id           = each.value.id
  name                = "group-mapper"
  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
}

# Audience Mapper for Vault to verify Token
resource "keycloak_openid_audience_protocol_mapper" "vault_audience" {
  realm_id  = keycloak_realm.infra_realm.id
  client_id = keycloak_openid_client.clients["vault"].id
  name      = "audience-mapper"

  included_custom_audience = "vault-infra"
  add_to_id_token          = true
  add_to_access_token      = true
}

# 5. Secret Storage in Vault (Using V2 for proper path handling)
resource "vault_kv_secret_v2" "oidc_clients" {
  provider = vault.production
  for_each = keycloak_openid_client.clients
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/oidc/clients/${each.key}"

  data_json = jsonencode({
    client_id     = each.value.client_id
    client_secret = random_password.client_secrets[each.key].result
    issuer        = "https://sso.keycloak.production.iac.internal/realms/${local.realm_id}"
  })
}

# 6. Test User & Groups Configuration
locals {
  all_groups = distinct(flatten([for u in var.oidc_users : u.groups]))
}

resource "keycloak_group" "groups" {
  for_each = toset(local.all_groups)
  realm_id = keycloak_realm.infra_realm.id
  name     = each.key

  lifecycle {
    prevent_destroy = false # Set to true in production if needed
  }
}

resource "keycloak_user" "users" {
  for_each       = var.oidc_users
  realm_id       = keycloak_realm.infra_realm.id
  username       = each.value.username
  enabled        = true
  email          = each.value.email
  first_name     = each.value.first_name
  last_name      = each.value.last_name
  email_verified = true

  initial_password {
    value     = each.value.password
    temporary = false
  }

  lifecycle {
    ignore_changes = [initial_password]
  }
}

resource "keycloak_user_groups" "user_assignments" {
  for_each = var.oidc_users
  realm_id = keycloak_realm.infra_realm.id
  user_id  = keycloak_user.users[each.key].id

  group_ids = [
    for g in each.value.groups : keycloak_group.groups[g].id
  ]
}
