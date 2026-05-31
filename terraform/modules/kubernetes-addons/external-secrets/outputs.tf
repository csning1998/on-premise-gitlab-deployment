
output "namespace" {
  value       = var.helm_config.namespace
  description = "The namespace external-secrets is deployed to"
}

output "chart_version" {
  value       = var.helm_config.version
  description = "The chart version of the deployed external-secrets"
}
