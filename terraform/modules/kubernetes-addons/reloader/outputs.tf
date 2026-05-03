
output "helm_release_metadata" {
  description = "Basic metadata of the Reloader Helm release"
  value = {
    name        = helm_release.reloader[0].metadata.name
    version     = helm_release.reloader[0].metadata.version
    app_version = helm_release.reloader[0].metadata.app_version
    revision    = helm_release.reloader[0].metadata.revision
    status      = helm_release.reloader[0].status
  }
}

output "namespace" {
  description = "The namespace where Reloader is deployed"
  value       = var.namespace
}
