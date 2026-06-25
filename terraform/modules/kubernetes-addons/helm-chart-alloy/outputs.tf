
output "helm_release_metadata" {
  description = "Basic metadata of the Alloy Helm release"
  value = {
    name        = helm_release.alloy.metadata.name
    version     = helm_release.alloy.metadata.chart
    app_version = helm_release.alloy.metadata.app_version
    revision    = helm_release.alloy.metadata.revision
    status      = helm_release.alloy.status
  }
}
