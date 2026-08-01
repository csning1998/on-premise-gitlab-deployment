
output "observability_endpoints" {
  description = "Internal Kubernetes service URLs for the observability stack, consumed by Stage 2 (Alloy scraping)"
  value = {
    mimir_query_url        = module.mimir.query_url
    mimir_remote_write_url = module.mimir.remote_write_url
    mimir_external_url     = "https://${local.mimir_fqdn}"
    loki_url               = module.loki.service_url
    grafana_fqdn           = local.grafana_fqdn
  }
}

output "grafana_helm_metadata" {
  description = "Detailed metadata of the deployed Grafana Helm release"
  value       = module.grafana.helm_release_metadata
}

output "alloy_client_cert_secret_name" {
  description = "Name of the Kubernetes secret holding the Alloy mTLS client certificate, for use in Phase 2 cross-cluster Alloy deployments"
  value       = module.alloy_client_cert.secret_name
}
