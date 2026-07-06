
output "mimir_tenant_id" {
  description = "Mimir tenant ID for this cluster's Alloy remote write; used by the observability layer to provision a Grafana datasource per tenant"
  value       = local.mimir_tenant_id
}

output "harbor_helm_metadata" {
  description = "Detailed metadata of the deployed Harbor Helm release"
  value       = module.harbor_core.helm_release_metadata
}
