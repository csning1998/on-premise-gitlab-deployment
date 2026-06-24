
output "helm_release_metadata" {
  description = "Basic metadata of the Mimir Helm release"
  value = {
    name        = helm_release.mimir.metadata.name
    version     = helm_release.mimir.metadata.chart
    app_version = helm_release.mimir.metadata.app_version
    revision    = helm_release.mimir.metadata.revision
    status      = helm_release.mimir.status
  }
}

output "query_url" {
  description = "Internal Kubernetes URL for the Mimir Prometheus-compatible query API, routed through the gateway"
  value       = "http://mimir-gateway.${var.helm_config.namespace}.svc.cluster.local:8080/prometheus"
}

output "remote_write_url" {
  description = "Internal Kubernetes URL for Prometheus remote-write ingestion via the Mimir gateway"
  value       = "http://mimir-gateway.${var.helm_config.namespace}.svc.cluster.local:8080/api/v1/push"
}
