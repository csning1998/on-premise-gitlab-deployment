
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

/**
 * Layer 00: Foundation Metadata - Network Topology
 * 
 * This file computes the exact IPv4 addresses, subnets, and MAC addresses 
 * for all components defined in the service_catalog.
 * 
 * Logic:
 * 1. Subnets: Each component is assigned a /24 subnet calculated from 
 *    the base CIDR and component's cidr_index. 
 * 2. Source: References the unified _flat_catalog (from locals-naming.tf) 
 *    to ensure a single point of iteration for all metadata layers.
 * 3. IPs: Node IPs are calculated based on node_ip_start and iteration counts. 
 * 4. VIPs: A fixed VIP (.250) is assigned to each segment for LB usage.
 */

locals {
  /**
   * 1. Generate Map of Network Topology
   *    Calculates CIDRs, VIPs, and host IP arrays for each component.
   */
  network_topology = {
    for key, item in local._flat_catalog : key => {
      segment_key    = key
      cidr_block     = cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index)
      
      # NAT calculation (Internal logic for gateway isolation)
      nat_gateway    = cidrhost(cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index - 124), 1)
      nat_cidr_block = cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index - 124)
      nat_cidr_index = item.config.cidr_index - 124

      nat_dhcp = {
        start = cidrhost(cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index - 124), 100)
        end   = cidrhost(cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index - 124), 199)
      }

      # Deterministic bridge name (Linux/Veth compatible)
      # References the pre-calculated hash prefix from _flat_catalog
      interface_alias = "v_${substr(replace(key, "-", ""), 0, 8)}_${substr(item.hash_prefix, 0, 4)}"
      vrid            = item.config.cidr_index
      ip_range        = item.config.ip_range
      ports           = coalesce(item.config.ports, {})
      tags            = coalesce(item.config.tags, [])

      # Fixed VIP (.250) for this segment
      vip = cidrhost(
        cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index),
        var.network_baseline.vip_offset
      )

      # Deterministic mac_address for stable networking across re-plans
      mac_address = "${var.network_baseline.mac_prefix}:${join(":", [
        substr(md5("${item.config.cidr_index}${key}"), 0, 2),
        substr(md5("${item.config.cidr_index}${key}"), 2, 2),
        substr(md5("${item.config.cidr_index}${key}"), 4, 2)
      ])}"

      # Complete list of IPs in the reserved range
      node_ips = [
        for i in range(item.config.ip_range.end_ip - item.config.ip_range.start_ip + 1) :
        cidrhost(cidrsubnet(var.network_baseline.cidr_block, 8, item.config.cidr_index), item.config.ip_range.start_ip + i)
      ]
    }
  }
}
