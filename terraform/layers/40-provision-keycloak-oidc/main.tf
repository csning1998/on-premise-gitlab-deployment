
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
  for_each = toset(["vault_frontend", "gitlab_frontend", "harbor_frontend", "harbor_bootstrapper", "gitlab_minio", "harbor_minio"])
  length   = 32
  special  = false
}

# 3. OIDC Clients
resource "keycloak_openid_client" "clients" {
  for_each = {
    vault_frontend = {
      client_id           = "vault-infra"
      name                = "Vault Infrastructure"
      valid_redirect_uris = local.vault_redirect_uris
    }
    gitlab_frontend = {
      client_id           = "gitlab-infra"
      name                = "GitLab Platform"
      valid_redirect_uris = ["${local.gitlab_frontend_url}/users/auth/openid_connect/callback"]
    }
    harbor_frontend = {
      client_id           = "harbor-infra"
      name                = "Harbor Registry"
      valid_redirect_uris = ["${local.harbor_frontend_url}/c/oidc/callback"]
    }
    gitlab_minio = {
      client_id           = "gitlab-minio-infra"
      name                = "GitLab MinIO Console"
      valid_redirect_uris = ["${local.gitlab_minio_url}/oauth_callback"]
    }
    harbor_minio = {
      client_id           = "harbor-minio-infra"
      name                = "Harbor MinIO Console"
      valid_redirect_uris = ["${local.harbor_minio_url}/oauth_callback"]
    }
    harbor_bootstrapper = {
      client_id           = "harbor-bootstrapper-infra"
      name                = "Harbor Bootstrapper"
      valid_redirect_uris = ["${local.harbor_bootstrapper_url}/c/oidc/callback"]
    }
  }

  realm_id              = keycloak_realm.infra_realm.id
  client_id             = each.value.client_id
  name                  = each.value.name
  enabled               = true
  access_type           = "CONFIDENTIAL"
  client_secret         = random_password.client_secrets[each.key].result
  standard_flow_enabled = true
  valid_redirect_uris   = each.value.valid_redirect_uris

  web_origins = [
    local.vault_frontend_url,
    local.gitlab_frontend_url,
    local.harbor_frontend_url,
    local.gitlab_minio_url,
    local.harbor_minio_url
  ]
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
  client_id = keycloak_openid_client.clients["vault_frontend"].id
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
    issuer        = "${local.keycloak_frontend_url}/realms/${local.realm_id}"
  })
}

# 6. Test User & Groups Configuration
# 6a. Root Level Groups (Parents)
resource "keycloak_group" "root_groups" {
  for_each = { for k, v in var.keycloak_groups : k => v if v.parent == null }
  realm_id = keycloak_realm.infra_realm.id
  name     = each.key

  attributes = each.value.attributes

  lifecycle {
    prevent_destroy = true
  }
}

# 6b. Subgroups (Children)
resource "keycloak_group" "subgroups" {
  for_each  = { for k, v in var.keycloak_groups : k => v if v.parent != null }
  realm_id  = keycloak_realm.infra_realm.id
  name      = each.key
  parent_id = keycloak_group.root_groups[each.value.parent].id

  attributes = each.value.attributes

  lifecycle {
    prevent_destroy = true
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
}

locals {
  # Helper to merge both group layers for easy lookup
  all_group_ids = merge(
    { for k, v in keycloak_group.root_groups : k => v.id },
    { for k, v in keycloak_group.subgroups : k => v.id }
  )
}

resource "keycloak_user_groups" "user_assignments" {
  for_each = var.oidc_users
  realm_id = keycloak_realm.infra_realm.id
  user_id  = keycloak_user.users[each.key].id

  group_ids = [
    for g in each.value.groups : local.all_group_ids[g]
  ]
}
