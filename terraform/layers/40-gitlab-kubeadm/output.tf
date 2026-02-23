
output "service_vip" {
  description = "The virtual IP assigned to the Vault service from Central LB topology."
  value       = local.service_vip
}

output "security_pki_bundle" {
  description = "PKI artifacts retrieved from the global topology."
  value       = local.security_pki_bundle
  sensitive   = true
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.credentials_system
  sensitive   = true
}

output "network_bindings" {
  description = "L2 network identity mapping (Verified from KVM Module)."
  value       = module.kubeadm_gitlab.network_bindings
}

output "network_parameters" {
  description = "L3 network configurations (Verified from KVM Module)."
  value       = module.kubeadm_gitlab.network_parameters
}

output "topology_cluster" {
  description = "The actual provisioned configuration for Vault nodes."
  value       = module.kubeadm_gitlab.cluster_nodes
}
