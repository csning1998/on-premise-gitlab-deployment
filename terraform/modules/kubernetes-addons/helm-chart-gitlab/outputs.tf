
output "helm_release_metadata" {
  description = "Status and metadata of the GitLab Helm release"
  value       = helm_release.gitlab.metadata
}
