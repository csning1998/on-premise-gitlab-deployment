
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

/**
 * Layer 00: Foundation Metadata - Volume Topology
 * 
 * This file calculates the deterministic storage volume names and pool 
 * mappings for all components that require persistent data disks.
 * 
 * Logic:
 * 1. Segments: Filters the unified _flat_catalog (from locals-naming.tf) 
 *    for components with data_disks.
 * 2. Mapping: Generates a Cartesian Product based on pre-calculated identities.
 * 3. Result: A flat map of volume names and their associated attributes 
 *    (pool, capacity, base_id) for downstream VM provisioning.
 */

locals {
  /**
   * 1. Construct the flat Volume Topology (Cartesian Product).
   *    Time Complexity: O(Segments * Nodes * Disks)
   * 
   *    This implementation references the "One Place" identity source in 
   *    locals-naming.tf to ensure zero naming redundancy.
   */
  _volume_topology_raw = flatten([
    for key, item in local._flat_catalog : [
      for i in range(item.config.ip_range.end_ip - item.config.ip_range.start_ip + 1) : [
        for disk in item.config.data_disks : {
          # Use pre-calculated identities from locals-naming.tf
          # Total string formatting here: 1 (volume_name suffixing)
          base_id      = item.cluster_name
          pool_name    = item.storage_pool_name
          volume_name  = "${item.cluster_name}-node-${item.config.ip_range.start_ip + i}-${disk.name_suffix}.qcow2"
          capacity_gib = disk.capacity_gib
        }
      ]
    ]
    if length(coalesce(item.config.data_disks, [])) > 0
  ])

  # Final searchable map used by Layer 10 (Virtual Machines)
  volume_topology = {
    for vol in local._volume_topology_raw : vol.volume_name => vol
  }
}
