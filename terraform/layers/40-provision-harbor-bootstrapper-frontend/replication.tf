
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

  # Destination is the central helm-charts project
  dest_namespace = "helm-charts"

  filters {
    name = each.value.resource_name
  }

  # Cron schedule: every 12 hours to keep it automated but not noisy
  schedule = "0 0 0,12 * * *"
  override = true
}
