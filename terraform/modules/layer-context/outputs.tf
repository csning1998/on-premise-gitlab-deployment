
output "svc_identity" {
  description = "SSoT identity object for the primary cluster."
  value       = local.svc_identity
}

output "svc_network" {
  description = "SSoT network object for the primary cluster."
  value       = local.svc_network
}

output "svc_pki_role" {
  description = "PKI role object for the primary cluster."
  value       = local.svc_pki_role
}

output "svc_fqdn" {
  description = "Primary FQDN derived from PKI DNS SANs."
  value       = local.svc_fqdn
}

output "network_infrastructure_map" {
  description = "Physical network infrastructure map keyed by network_tier, ready for middleware consumption."
  value       = local.network_infrastructure_map
}

output "primary_net_config" {
  description = "Network infrastructure configuration for the primary role's network tier."
  value       = local.primary_net_config
}

output "tier_network_map" {
  description = "Full global_topology_network entry keyed by network_tier, exposing ports and node_ips for downstream layers needing non-LB topology data (e.g. metrics endpoints)."
  value       = local.tier_network_map
}

output "sec_vm_credentials" {
  description = "VM system credentials."
  value       = local.sec_vm_credentials
  sensitive   = true
}

output "sys_vault_endpoint" {
  description = "Vault HTTPS address constructed from vault_sys_vip. Null for layers without Vault Agent integration."
  value       = local.sys_vault_endpoint
}

output "storage_pool_name" {
  description = "Storage pool name from primary SSoT identity."
  value       = local.storage_pool_name
}

output "topology_cluster" {
  description = "Assembled topology_cluster object for ha-service-kvm-general middleware."
  value       = local.topology_cluster
}

output "node_identities" {
  description = "Map of role to SSoT identity, for middleware node name resolution."
  value       = local.node_identities
}

output "vault_agent_identity_base" {
  description = "Partial Vault Agent identity (excludes secret_id). Null for layers without Vault PKI integration."
  value       = local.vault_agent_identity_base
  sensitive   = true
}

output "global_mss" {
  description = "Global MSS value from network baseline."
  value       = var.global_network_baseline.global_mss
}

output "global_mtu" {
  description = "Global MTU value from network baseline."
  value       = var.global_network_baseline.global_mtu
}

output "node_exporter_port" {
  description = "Global Node Exporter listen port from network baseline, for VM fleet observability scrape targets."
  value       = var.global_network_baseline.node_exporter_port
}

output "primary_context" {
  description = "Full primary context entry from segments_map. Exposes s_name/c_name for layer-specific filter logic."
  value       = local.primary_context
}

output "components_context" {
  description = "Full components_context map. Used by multi-role layers that need per-role context beyond the primary."
  value       = local.components_context
}

output "asymmetric_static_routes" {
  description = "Static routes keyed by network_tier. Each tier's routes cover all other clusters via that tier's own LB VIP, ensuring on-link gateway validity."
  value       = local.asymmetric_static_routes

  precondition {
    condition = alltrue([
      for tier, route_lists in local.asymmetric_static_routes_grouped :
      length(distinct([for rl in route_lists : jsonencode(rl)])) == 1
    ])
    error_message = "One or more network_tier values are shared by roles from different clusters. Each tier must map to exactly one cluster for route deduplication to be correct."
  }
}

output "vault_sys_vip" {
  description = "Raw Vault system VIP address without protocol or port. Null for layers without Vault integration."
  value       = var.vault_sys_vip
}

output "all_vault_agent_identity_bases" {
  description = "Per-role Vault Agent identity bases (excludes secret_id). Keyed by target_clusters role. Empty map for layers without Vault integration."
  value       = local.all_vault_agent_identity_bases
  sensitive   = true
}

output "global_topology_network" {
  description = "Pass-through of SSoT network map for resolving external component ports safely through context."
  value       = var.global_topology_network
}
