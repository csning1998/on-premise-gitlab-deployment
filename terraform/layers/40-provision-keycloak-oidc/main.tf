
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
      client_id           = "vault-infra"
      name                = "Vault Infrastructure"
      valid_redirect_uris = ["https://vault.production.iac.internal/ui/vault/auth/oidc/oidc/callback"]
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
  for_each   = keycloak_openid_client.clients
  realm_id   = keycloak_realm.infra_realm.id
  client_id  = each.value.id
  name       = "group-mapper"
  claim_name = "groups"
  full_path  = false
}

# 5. Secret Storage in Vault
resource "vault_generic_secret" "oidc_clients" {
  provider = vault.production
  for_each = keycloak_openid_client.clients
  path     = "secret/on-premise-gitlab-deployment/oidc/clients/${each.key}"

  data_json = jsonencode({
    client_id     = each.value.client_id
    client_secret = random_password.client_secrets[each.key].result
    issuer        = "https://sso.keycloak.production.iac.internal/realms/${local.realm_id}"
  })
}
