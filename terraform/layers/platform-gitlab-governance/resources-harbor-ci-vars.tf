
# Harbor CI registry credentials per team subgroup.
# Refer tp README.md "Harbor CI Registry Credentials" for the design and the raw=true rationale.
locals {
  team_subgroups = {
    for id, meta in local.kc_groups :
    id => meta
    if meta.parent == local.target_org_name && lookup(meta.attributes, "type", "") == "team"
  }
}

data "vault_kv_secret_v2" "harbor_ci_robot" {
  for_each = local.team_subgroups
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor/robots/${each.key}"
}

resource "gitlab_group_variable" "ci_registry_user" {
  for_each  = local.team_subgroups
  group     = gitlab_group.subgroups[each.key].id
  key       = "CI_REGISTRY_USER"
  value     = data.vault_kv_secret_v2.harbor_ci_robot[each.key].data["username"]
  raw       = true
  masked    = false
  protected = false
}

resource "gitlab_group_variable" "ci_registry_password" {
  for_each  = local.team_subgroups
  group     = gitlab_group.subgroups[each.key].id
  key       = "CI_REGISTRY_PASSWORD"
  value     = data.vault_kv_secret_v2.harbor_ci_robot[each.key].data["password"]
  raw       = true
  masked    = true
  protected = false
}
