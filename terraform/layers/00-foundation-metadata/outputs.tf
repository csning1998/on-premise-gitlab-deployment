
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

/**
 * Layer 00: Foundation Metadata - Outputs
 *
 * This file exposes the Single Source of Truth (SSoT) to the rest of the
 * infrastructure via the Terraform state.
 *
 * Design Principles (MECE):
 * 1. Hierarchies are split into independent domain maps:
 *    - Network: IP/MAC/CIDR attributes.
 *    - Identity: Naming/Pool/Bridge attributes.
 *    - PKI: DNS SANs and Organizational metadata.
 * 2. Sensitive data is marked accordingly for secure transport.
 */

# 1. Global Global/Governance Attributes
output "global_domain_suffix" {
  description = "The root domain suffix (e.g., iac.local) for all downstream layers."
  value       = var.domain_suffix
}

output "global_pki_settings" {
  description = "Global PKI Identity Settings for downstream layers (e.g. Vault PKI)."
  value       = var.pki_settings
}

# 2. Domain Topology Outputs (MECE Split)
output "global_topology_network" {
  description = "Granular network attributes for all services/components (IPs, MACs, VIPs)."
  value = {
    for s_name, s in var.service_catalog : s_name => {
      for c_name, c in s.components : c_name => local.network_topology["${s_name}-${c_name}"]
    }
  }
}

output "global_topology_identity" {
  description = "Granular cluster/node/storage identity and naming attributes."
  value = {
    for s_name, s in var.service_catalog : s_name => {
      for c_name, c in s.components : c_name => local.identity_map["${s_name}-${c_name}"]
    }
  }
}

output "global_volume_map" {
  description = "Pure MECE mapping of calculated storage volume attributes (Pools and physical Data Disks)."
  value       = local.volume_topology
}

# 3. Security & PKI Artifacts
output "global_pki_map" {
  description = "Pure mapping of DNS SANs and organizational context for certificate generation."
  value       = local.pki_map
}

output "global_vault_pki" {
  description = "Base64 encoded TLS artifacts for the Bootstrap Vault instance."
  sensitive   = true
  value = {
    ca_cert        = base64encode(tls_self_signed_cert.root_ca.cert_pem)
    server_cert    = base64encode(tls_locally_signed_cert.vault_server.cert_pem)
    server_key     = base64encode(tls_private_key.vault_server.private_key_pem)
    haproxy_bundle = base64encode("${tls_locally_signed_cert.vault_server.cert_pem}\n${tls_private_key.vault_server.private_key_pem}")
  }
}
