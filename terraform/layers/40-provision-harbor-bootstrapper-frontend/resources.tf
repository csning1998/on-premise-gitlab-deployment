
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
  name     = "on-premise-gitlab-deployment/harbor-bootstrapper/robot"
  data_json = jsonencode({
    username_puller = harbor_robot_account.helm_puller.full_name
    password_puller = harbor_robot_account.helm_puller.secret
    username_pusher = harbor_robot_account.helm_pusher.full_name
    password_pusher = harbor_robot_account.helm_pusher.secret
  })
}

module "ansible_sync_oci" {
  source = "../../modules/cluster-provision/ansible-runner"

  depends_on = [
    vault_kv_secret_v2.robot_helm_creds,
    harbor_project.proxy_oci,
    harbor_project.proxy_projects,
    harbor_registry.proxy_registries
  ]

  status_trigger = local.state.harbor_bootstrapper.topology_node
  ansible_config = local.ansible_config
  inventory_data = local.inventory_data
  credentials_vm = local.credentials_vm
  extra_vars     = local.ansible_extra_vars
}
