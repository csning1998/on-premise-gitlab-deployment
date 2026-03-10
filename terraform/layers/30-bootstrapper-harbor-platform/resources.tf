
resource "harbor_registry" "proxy_registries" {
  for_each = local.proxy_caches

  name          = each.value.registry_name
  endpoint_url  = each.value.endpoint_url
  provider_name = each.value.provider_name
}

resource "harbor_project" "proxy_projects" {
  for_each = local.proxy_caches

  name          = each.value.project_name
  public        = "true"
  force_destroy = true
  registry_id   = harbor_registry.proxy_registries[each.key].registry_id
}
