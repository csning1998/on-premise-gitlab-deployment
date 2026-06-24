
output "helm_release_metadata" {
  description = "Basic metadata of the Loki Helm release"
  value = {
    name        = helm_release.loki.metadata.name
    version     = helm_release.loki.metadata.chart
    app_version = helm_release.loki.metadata.app_version
    revision    = helm_release.loki.metadata.revision
    status      = helm_release.loki.status
  }
}

output "service_url" {
  description = "Internal Kubernetes URL for the Loki log query and push API"
  value       = "http://loki.${var.helm_config.namespace}.svc.cluster.local:3100"
}
