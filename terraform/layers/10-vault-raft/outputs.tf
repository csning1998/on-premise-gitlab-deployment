
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = local.net_service_vip
}

output "security_pki_bundle" {
  description = "PKI artifacts retrieved from the global topology."
  value       = local.pki_global_ca
  sensitive   = true
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "network_bindings" {
  description = "L2 network identity mapping (Verified from KVM Module)."
  value       = module.vault_cluster.network_bindings
}

output "network_parameters" {
  description = "L3 network configurations (Verified from KVM Module)."
  value       = module.vault_cluster.network_parameters
}

output "topology_cluster" {
  description = "The actual provisioned configuration for Vault nodes."
  value       = module.vault_cluster.cluster_nodes
}
