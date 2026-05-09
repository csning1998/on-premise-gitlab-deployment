
output "issuer_name" {
  description = "The name of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_name
}

output "issuer_kind" {
  description = "The kind of the Cert-Manager issuer provisioned in Layer 40"
  value       = module.platform_trust_engine.issuer_kind
}
