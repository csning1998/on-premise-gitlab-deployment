
output "observability_endpoints" {
  description = "Internal Kubernetes service URLs for the observability stack, consumed by Stage 2 (Alloy scraping)"
  value = {
    mimir_query_url        = module.mimir.query_url
    mimir_remote_write_url = module.mimir.remote_write_url
    loki_url               = module.loki.service_url
    grafana_fqdn           = local.grafana_fqdn
  }
}

output "grafana_helm_metadata" {
  description = "Detailed metadata of the deployed Grafana Helm release"
  value       = module.grafana.helm_release_metadata
}
