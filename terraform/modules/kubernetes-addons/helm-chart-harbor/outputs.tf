
output "helm_release_metadata" {
  description = "Basic metadata of the Harbor Helm release"
  value = {
    name        = helm_release.harbor.metadata.name
    version     = helm_release.harbor.metadata.version
    app_version = helm_release.harbor.metadata.app_version
    revision    = helm_release.harbor.metadata.revision
    status      = helm_release.harbor.status
  }
}
