
output "helm_release_metadata" {
  description = "Basic metadata of the Grafana Helm release"
  value = {
    name        = helm_release.grafana.metadata.name
    version     = helm_release.grafana.metadata.chart
    app_version = helm_release.grafana.metadata.app_version
    revision    = helm_release.grafana.metadata.revision
    status      = helm_release.grafana.status
  }
}
