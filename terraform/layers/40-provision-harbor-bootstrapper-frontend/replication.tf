
resource "harbor_registry" "external" {
  for_each      = local.external_registries
  name          = each.value.name
  endpoint_url  = each.value.endpoint_url
  provider_name = each.value.provider_name
}

resource "harbor_replication" "charts" {
  for_each    = local.replication_policies
  name        = "sync-${each.key}"
  action      = "pull"
  registry_id = harbor_registry.external[each.value.registry_key].registry_id

  dest_namespace = harbor_project.proxy_oci["helm_charts"].name

  filters {
    name = each.value.resource_name
  }

  schedule = "manual"
  override = true
}
