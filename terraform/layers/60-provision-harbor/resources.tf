
# Harbor projects, OIDC group bindings, proxy caches, and per team CI robots.
# Refer to README.md "Harbor Project and RBAC Provisioning" for the design.

resource "harbor_project" "shared" {
  name   = "shared"
  public = false
}

resource "harbor_project" "team" {
  for_each = local.team_groups
  name     = "team-${each.key}"
  public   = false
}

resource "harbor_group" "team_groups" {
  for_each   = local.team_groups
  group_name = each.key
  group_type = 3 # 3 = OIDC
}

resource "harbor_group" "role_groups" {
  for_each   = local.role_groups
  group_name = each.key
  group_type = 3 # 3 = OIDC
}

resource "harbor_project_member_group" "shared_team_developer" {
  for_each   = local.team_groups
  project_id = harbor_project.shared.id
  role       = "developer"
  type       = "oidc"
  group_id   = tonumber(split("/", harbor_group.team_groups[each.key].id)[2])

  lifecycle {
    ignore_changes = [group_name]
  }
}

resource "harbor_project_member_group" "shared_leads_maintainer" {
  for_each   = local.role_groups
  project_id = harbor_project.shared.id
  role       = "maintainer"
  type       = "oidc"
  group_id   = tonumber(split("/", harbor_group.role_groups[each.key].id)[2])

  lifecycle {
    ignore_changes = [group_name]
  }
}

resource "harbor_project_member_group" "team_self_developer" {
  for_each   = local.team_groups
  project_id = harbor_project.team[each.key].id
  role       = "developer"
  type       = "oidc"
  group_id   = tonumber(split("/", harbor_group.team_groups[each.key].id)[2])

  lifecycle {
    ignore_changes = [group_name]
  }
}

resource "harbor_project_member_group" "team_leads_maintainer" {
  for_each = {
    for pair in flatten([
      for team_key in keys(local.team_groups) : [
        for role_key in keys(local.role_groups) : {
          key      = "${team_key}__${role_key}"
          team_key = team_key
          role_key = role_key
        }
      ]
    ]) : pair.key => pair
  }

  project_id = harbor_project.team[each.value.team_key].id
  role       = "maintainer"
  type       = "oidc"
  group_id   = tonumber(split("/", harbor_group.role_groups[each.value.role_key].id)[2])

  lifecycle {
    ignore_changes = [group_name]
  }
}

resource "harbor_registry" "proxy_upstream" {
  for_each      = local.state.harbor_bootstrapper.proxy_caches
  name          = "ext-${each.value.project_name}"
  endpoint_url  = each.value.endpoint_url
  provider_name = each.value.provider_name
}

resource "harbor_project" "mirror" {
  for_each    = local.state.harbor_bootstrapper.proxy_caches
  name        = each.value.project_name
  public      = true
  registry_id = harbor_registry.proxy_upstream[each.key].registry_id
}

resource "harbor_robot_account" "team_ci" {
  for_each    = local.team_groups
  name        = "ci-${each.key}"
  description = "GitLab CI robot for team ${each.key} (${each.value.description})"
  level       = "system"

  permissions {
    kind      = "project"
    namespace = harbor_project.team[each.key].name
    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "list"
      resource = "repository"
    }
    access {
      action   = "create"
      resource = "tag"
    }
    access {
      action   = "delete"
      resource = "tag"
    }
  }

  permissions {
    kind      = "project"
    namespace = harbor_project.shared.name
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "list"
      resource = "repository"
    }
  }
}

resource "vault_kv_secret_v2" "team_robot_creds" {
  provider = vault.production
  for_each = local.team_groups
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/robots/${each.key}"

  data_json = jsonencode({
    username = harbor_robot_account.team_ci[each.key].full_name
    password = harbor_robot_account.team_ci[each.key].secret
  })
}
