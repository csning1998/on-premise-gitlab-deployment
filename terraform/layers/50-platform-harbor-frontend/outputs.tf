
output "harbor_helm_metadata" {
  description = "Detailed metadata of the deployed Harbor Helm release"
  value       = module.harbor_core.helm_release_metadata
}
