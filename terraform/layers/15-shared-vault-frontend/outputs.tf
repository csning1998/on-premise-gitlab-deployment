
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = module.context.primary_net_config.lb_config.vip
}

output "security_pki_bundle_b64" {
  description = "The PKI bundle for the Vault server."
  value       = module.context.global_vault_pki_b64
  sensitive   = true
}

output "ca_cert_path" {
  description = "The absolute path to the local Bootstrap CA certificate."
  value       = abspath(local_file.bootstrap_ca.filename)
}

output "vault_api_port" {
  description = "Vault API frontend port for L40 consumption."
  value       = module.context.primary_net_config.lb_config.ports["api"].frontend_port
}
