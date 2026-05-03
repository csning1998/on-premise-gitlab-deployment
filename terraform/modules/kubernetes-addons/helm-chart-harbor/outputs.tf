
output "helm_release_metadata" {
  description = "Status and metadata of the Harbor Helm release"
  value       = helm_release.harbor.metadata
}
