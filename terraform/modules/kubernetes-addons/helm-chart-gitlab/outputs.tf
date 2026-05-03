
output "helm_release_metadata" {
  description = "Basic metadata of the GitLab Helm release"
  value = {
    name        = helm_release.gitlab.metadata.name
    version     = helm_release.gitlab.metadata.version
    app_version = helm_release.gitlab.metadata.app_version
    revision    = helm_release.gitlab.metadata.revision
    status      = helm_release.gitlab.status
  }
}
