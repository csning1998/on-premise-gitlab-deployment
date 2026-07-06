
resource "harbor_registry" "proxy_registries" {
  for_each      = local.proxy_caches
  name          = each.value.registry_name
  endpoint_url  = each.value.endpoint_url
  provider_name = each.value.provider_name
}

resource "harbor_project" "proxy_projects" {
  for_each      = local.proxy_caches
  name          = each.value.project_name
  public        = true
  force_destroy = true
  registry_id   = harbor_registry.proxy_registries[each.key].registry_id
}

resource "harbor_project" "proxy_oci" {
  for_each      = local.proxy_oci
  name          = each.value.name
  public        = true
  force_destroy = true
}

resource "harbor_robot_account" "helm_puller" {
  name        = "helm-puller"
  description = "System level Robot account for Helm Provider to pull from local and proxy caches"

  level = "system"

  permissions {
    kind      = "project"
    namespace = harbor_project.proxy_oci["helm_charts"].name
    access {
      action   = "pull"
      resource = "repository"
    }
  }

  dynamic "permissions" {
    for_each = harbor_project.proxy_projects
    content {
      kind      = "project"
      namespace = permissions.value.name
      access {
        action   = "pull"
        resource = "repository"
      }
    }
  }
}

resource "harbor_robot_account" "helm_pusher" {
  name        = "helm-pusher"
  description = "Robot account for pushing Helm charts to OCI registry"
  level       = "project"
  permissions {
    kind      = "project"
    namespace = harbor_project.proxy_oci["helm_charts"].name
    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
  }
}

resource "vault_kv_secret_v2" "robot_helm_creds" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor-bootstrapper/robot"
  data_json = jsonencode({
    username_puller = harbor_robot_account.helm_puller.full_name
    password_puller = harbor_robot_account.helm_puller.secret
    username_pusher = harbor_robot_account.helm_pusher.full_name
    password_pusher = harbor_robot_account.helm_pusher.secret
  })
}

# 3. Harbor OIDC Authentication Configuration
# Configures Harbor Bootstrapper to use Keycloak for Identity.
resource "harbor_config_auth" "main" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Keycloak"
  oidc_endpoint      = data.terraform_remote_state.keycloak_oidc.outputs.issuer_url
  oidc_client_id     = data.terraform_remote_state.keycloak_oidc.outputs.oidc_clients["harbor_bootstrapper"].client_id
  oidc_client_secret = data.terraform_remote_state.keycloak_oidc.outputs.oidc_clients["harbor_bootstrapper"].client_secret
  oidc_scope         = "openid,profile,email"
  oidc_verify_cert   = false
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"

  # Map the Keycloak 'admin' group to Harbor System Administrator
  oidc_admin_group = "admin"
}

# 4. Infrastructure Admin Group Mapping
resource "harbor_group" "infra_admins" {
  group_name = "admin"
  group_type = 3 # OIDC Group
}
