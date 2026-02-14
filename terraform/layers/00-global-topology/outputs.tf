
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

output "domain_suffix" {
  description = "The root domain suffix (e.g., iac.local) for all downstream layers."
  value       = var.domain_suffix
}

output "pki_settings" {
  description = "Global PKI Identity Settings for downstream layers (e.g. Vault PKI)."
  value       = var.pki_settings
}

# For Load Balancer Usage: Only cares about how many network segments to set
output "network_segments" {
  description = "Flat map of all network segments for LB iteration."
  value       = local.network_topology
}

/**
 * For Vault/App Usage: Needs to know the complete identity and network mapping
 * 1. meta: Inherit original definition
 * 2. network: Service Network Identity. Corresponds to local.network_topology["service_name"]
 * 3. components: Internal Component Roles
 * 4. dependencies: Dependencies Structure. Include dependency service "network info" and "role info"
 *    - network info: Corresponds to local.network_topology["service_name-dependency_name"]
 *    - role info: Corresponds to local.naming_map["service_name-dependency_name"]
 */

output "service_structure" {
  description = "Hierarchical structure combining Catalog, Network, and Naming."
  value = {
    for s in var.service_catalog : s.name => {
      meta    = s
      network = local.network_topology[s.name]

      components = {
        for c_key, c_val in s.components : c_key => local.naming_map["${s.name}-${c_key}"]
      }

      dependencies = {
        for d_key, d_val in s.dependencies : d_key => merge(
          local.network_topology["${s.name}-${d_key}"],
          { role = local.naming_map["${s.name}-${d_key}"] }
        )
      }
    }
  }
}
