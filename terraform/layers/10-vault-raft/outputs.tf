
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = local.service_vip
}

output "vault_ca_cert" {
  description = "The Certificates content of the Vault Cluster"
  value = {
    ca_cert = module.vault_tls_generator.ca_cert_pem # for PKI
  }
}
