
output "helm_release_metadata" {
  description = "Basic metadata of the kube-state-metrics Helm release"
  value = {
    name        = helm_release.kube_state_metrics.metadata.name
    version     = helm_release.kube_state_metrics.metadata.version
    app_version = helm_release.kube_state_metrics.metadata.app_version
    revision    = helm_release.kube_state_metrics.metadata.revision
    status      = helm_release.kube_state_metrics.status
  }
}
