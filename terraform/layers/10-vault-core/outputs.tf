
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = var.vault_compute.ha_config.virtual_ip
}
