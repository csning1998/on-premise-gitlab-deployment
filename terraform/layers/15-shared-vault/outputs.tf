
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = local.net_physical_infra.lb_config.vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_vm_creds
  sensitive   = true
}

output "security_pki_bundle" {
  description = "The PKI bundle for the Vault server."
  value       = local.pki_global_ca
  sensitive   = true
}
