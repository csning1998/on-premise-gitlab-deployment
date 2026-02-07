
output "issuer_name" {
  description = "The name of the generated ClusterIssuer. Used by service modules to request certificates."
  value       = var.issuer_config.name
}

output "issuer_kind" {
  description = "The kind of the generated issuer (ClusterIssuer). Used in cert-manager annotations."
  value       = "ClusterIssuer"
}

output "vault_auth_path" {
  description = "The mount path of the Kubernetes Auth Backend in Vault."
  value       = var.vault_config.auth_path
}

output "vault_role_name" {
  description = "The Vault Role name bound to this issuer. Useful for debugging or policy verification."
  value       = var.issuer_config.vault_role_name
}

output "cert_manager_namespace" {
  description = "The namespace where cert-manager and its related secrets are located."
  value       = var.helm_config.namespace
}
