
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = local.service_vip
}
