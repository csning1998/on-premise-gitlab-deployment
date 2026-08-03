
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

/**
 * foundation-metadata: Outputs
 *
 * This file exposes the Single Source of Truth (SSoT) to the rest of the
 * infrastructure via the Terraform state. Every output below preserves the
 * name and shape it held before this layer became a shim over the
 * service-catalog module and meta-platform's global metadata. No downstream
 * layer requires any change as a result.
 *
 * Design Principles (MECE):
 * 1. Hierarchies are split into independent domain maps:
 *    - Network: IP/MAC/CIDR attributes.
 *    - Identity: Naming/Pool/Bridge attributes.
 *    - PKI: DNS SANs and Organizational metadata.
 * 2. Sensitive data is marked accordingly for secure transport.
 */

# 1. Global Global/Governance Attributes
output "vault_kv_namespace" {
  description = "Project-level Vault KV namespace prefix for all generated credentials."
  value       = var.vault_kv_namespace
}

output "global_credential_paths" {
  description = "Mount-relative Vault KV paths for all service component credentials, derived from the service catalog."
  value = {
    for s_name, s in var.service_catalog : s_name => {
      for c_name, c in s.components : c_name =>
      "${var.vault_kv_namespace}/${s_name}/${c_name}"
    }
  }
}

output "global_domain_suffix" {
  description = "The root domain suffix (e.g., iac.local) for all downstream layers."
  value       = data.terraform_remote_state.platform_metadata.outputs.global_domain_suffix
}

output "global_network_baseline" {
  description = "Base network configuration including CIDR, VIP offsets, and global MTU/MSS settings."
  value       = data.terraform_remote_state.platform_metadata.outputs.global_network_baseline
}

output "global_pki_config" {
  description = "Global PKI Identity Settings for downstream layers (e.g. Vault PKI)."
  value       = data.terraform_remote_state.platform_metadata.outputs.global_pki_config
}

# 2. Domain Topology Outputs (MECE Split)
output "global_topology_network" {
  description = "Granular network attributes for all services/components (IPs, MACs, VIPs)."
  value       = module.service_catalog.topology_network
}

output "global_topology_identity" {
  description = "Granular cluster/node/storage identity and naming attributes."
  value       = module.service_catalog.topology_identity
}

output "global_volume_map" {
  description = "Pure MECE mapping of calculated storage volume attributes (Pools and physical Data Disks)."
  value       = module.service_catalog.volume_map
}

# 3. Security & PKI Artifacts
output "global_pki_map" {
  description = "Pure mapping of DNS SANs and organizational context for certificate generation."
  value       = module.service_catalog.pki_map
}

output "global_dns_records" {
  description = "SSoT mapping of all infrastructure hostnames to their respective VIPs."
  value       = module.service_catalog.dns_records
}
