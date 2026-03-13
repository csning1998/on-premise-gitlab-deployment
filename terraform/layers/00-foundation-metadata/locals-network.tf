
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

locals {

  /**
   * Calculate the specific network information for each service.
   * 1. Parent Service Segment for Main Frontend VIP
   *    Only generate when this Service needs an independent VIP (usually needed)
   *    - key: "service_name"
   *    - cidr_index: svc_data.cidr_index
   * 2. Dependency Segments for Backend VIPs
   *    Include dependency service "network info" and "role info"
   *    - key: "service_name-dependency_name"
   *    - cidr_index: dep_data.cidr_index
   */

  network_segments_list = flatten([
    for s in var.service_catalog : concat(
      [{
        key        = s.name
        cidr_index = s.cidr_index
        ip_range   = s.ip_range
        ports      = s.ports
        tags       = s.tags
      }],
      [for d_key, d_data in s.dependencies : {
        key        = "${s.name}-${d_key}"
        cidr_index = d_data.cidr_index
        ip_range   = d_data.ip_range
        ports      = d_data.ports
        tags       = d_data.tags
      }]
    )
  ])

  /**
   * Convert back to Map for IP/MAC calculation
   * 1. cidr_block: 172.16.X.0/24
   * 2. nat_cidr_block: 172.16.X.0/24
   * 3. nat_gateway: 172.16.X.1
   * 4. interface_alias: v_ + segment.key + MD5 Hash (e.g., v_'service_name'_'md5_hash')
   * 5. vrid: X
   * 6. ip_range: { start_ip = 200, end_ip = 220 }
   * 7. ports: { frontend_port = 80, backend_port = 443 }
   * 8. tags: ["with-128-etcd", "with-127-postgres"]
   * 9. vip: 172.16.X.250
   * 10. mac_address: Deterministic Hashing. Ensure "service_name" always generates the same MAC, regardless of its position in the list
   */
  network_topology = {
    for seg in local.network_segments_list : seg.key => {

      segment_key    = seg.key
      cidr_block     = cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index)
      nat_gateway    = cidrhost(cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index - 124), 1)
      nat_cidr_block = cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index - 124)
      nat_cidr_index = seg.cidr_index - 124

      nat_dhcp = {
        start = cidrhost(cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index - 124), 100)
        end   = cidrhost(cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index - 124), 199)
      }

      interface_alias = "v_${substr(replace(seg.key, "-", ""), 0, 8)}_${substr(md5("${local.network_baseline.cidr_block}${seg.key}"), 0, 4)}"
      vrid            = seg.cidr_index
      ip_range        = seg.ip_range
      ports           = seg.ports
      tags            = seg.tags

      vip = cidrhost(
        cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index),
        local.network_baseline.vip_offset
      )

      mac_address = "${local.network_baseline.mac_prefix}:${join(":", [
        substr(md5("${seg.cidr_index}${seg.key}"), 0, 2),
        substr(md5("${seg.cidr_index}${seg.key}"), 2, 2),
        substr(md5("${seg.cidr_index}${seg.key}"), 4, 2)
      ])}"
    }
  }
}
