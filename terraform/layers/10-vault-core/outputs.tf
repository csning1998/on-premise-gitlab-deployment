
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = var.vault_compute.ha_config.virtual_ip
}

output "vault_ca_cert" {
  description = "The Root CA Certificate content (Public Key) of the Vault Cluster"
  value       = module.vault_tls.ca_cert_pem
  sensitive   = false
}
