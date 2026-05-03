
output "helm_release_metadata" {
  description = "Status and metadata of the Reloader Helm release"
  value       = helm_release.reloader[0].metadata
}

output "namespace" {
  description = "The namespace where Reloader is deployed"
  value       = var.namespace
}
