
output "harbor_hostname" {
  value = local.harbor_hostname
}

output "platform_issuer_name" {
  description = "The name of the ClusterIssuer created by the trust engine"
  value       = module.platform_trust_engine.issuer_name
}

output "platform_issuer_kind" {
  description = "The kind of the issuer (ClusterIssuer)"
  value       = module.platform_trust_engine.issuer_kind
}
