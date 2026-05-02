
output "secret_name" {
  description = "The name of the secret where the certificate is stored."
  value       = var.name
}

output "certificate_name" {
  description = "The name of the certificate resource."
  value       = var.name
}

output "namespace" {
  description = "The namespace of the certificate."
  value       = var.namespace
}
