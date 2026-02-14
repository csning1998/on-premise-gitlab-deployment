
locals {
  # Data Ingestion
  global_topology  = data.terraform_remote_state.topology.outputs
  raw_segments     = data.terraform_remote_state.topology.outputs.network_segments
  service_meta     = local.global_topology.service_structure[var.service_catalog_name].meta
  domain_suffix    = local.global_topology.domain_suffix
  cluster_name     = "${local.service_meta.name}-${local.service_meta.project_code}"
  node_name_prefix = "${local.cluster_name}-node"
}

locals {
  # Deterministic Ordering
  sorted_node_keys = sort(keys(var.node_config))

  sorted_segment_keys = sort([
    for k, v in local.raw_segments : k
    if k != var.service_catalog_name
  ])

  node_naming_map = {
    for idx, key in local.sorted_node_keys :
    key => "${local.node_name_prefix}-${format("%02d", idx)}"
  }

  # MAC Address Derivation Base (From Layer 00 "central-lb")
  # Example: 52:54:00:0a:a4:f5 (where 0a is VRID 10)
  lb_base_mac_parts = split(":", local.raw_segments[var.service_catalog_name].mac_address)

  # Infrastructure Network Config
  my_segment = local.raw_segments[var.service_catalog_name]
}

locals {
  # Infrastructure Network Config
  infra_network = {
    nat = {
      gateway      = local.my_segment.nat_gateway
      cidrv4       = local.my_segment.nat_cidr_block
      dhcp         = local.my_segment.nat_dhcp
      name_network = "iac-${var.service_catalog_name}-nat"
      name_bridge  = "iac-mgmt-br"
    }
    hostonly = {
      gateway      = cidrhost(local.my_segment.cidr_block, 1)
      cidrv4       = local.my_segment.cidr_block
      name_network = "iac-${var.service_catalog_name}-hostonly"
      name_bridge  = "iac-internal-br"
    }
  }
  storage_pool_name = "iac-${local.service_meta.project_code}-${local.service_meta.name}"
  allowed_subnet    = local.my_segment.cidr_block
}

locals {
  # Payload Construction
  nodes_configuration = {
    for node_name, node_spec in var.node_config : local.node_naming_map[node_name] => {
      vcpu            = node_spec.vcpu
      ram             = node_spec.ram
      base_image_path = var.base_image_path

      interfaces = flatten([
        # Interface 1: NAT (Management) [ens3]
        # Logic: Use Layer 00 Base MAC, but force 4th octet (VRID) to '00' for Management differentiation
        [{
          network_name = local.infra_network.nat.name_network
          mac = format("%s:%s:%s:00:%s:%02x",
            local.lb_base_mac_parts[0], # 52
            local.lb_base_mac_parts[1], # 54
            local.lb_base_mac_parts[2], # 00
            # 4th octet forced to 00 for NAT
            local.lb_base_mac_parts[4],
            (parseint(local.lb_base_mac_parts[5], 16) + index(local.sorted_node_keys, node_name)) % 256
          )
          addresses      = [] # DHCP
          wait_for_lease = true
        }],

        # Interface 2: HostOnly (Internal) [ens4]
        # Logic: Inherit Layer 00 Base MAC (VRID=10) directly + Node Index
        [{
          network_name = local.infra_network.hostonly.name_network
          mac = format("%s:%s:%s:%s:%s:%02x",
            local.lb_base_mac_parts[0],
            local.lb_base_mac_parts[1],
            local.lb_base_mac_parts[2],
            local.lb_base_mac_parts[3], # Keep VRID (e.g., 0a)
            local.lb_base_mac_parts[4],
            (parseint(local.lb_base_mac_parts[5], 16) + index(local.sorted_node_keys, node_name)) % 256
          )
          addresses = [
            format("%s/%s",
              cidrhost(local.my_segment.cidr_block, node_spec.ip_suffix),
              split("/", local.my_segment.cidr_block)[1]
            )
          ]
          wait_for_lease = false
        }],

        # Interface 3..N: Service Segments [ens5...]
        # Logic: Use each Segment's Layer 00 MAC + Node Index
        [
          for seg_key in local.sorted_segment_keys : {
            network_name = seg_key
            alias        = local.raw_segments[seg_key].interface_alias
            mac = format("%s:%02x",
              join(":", slice(split(":", local.raw_segments[seg_key].mac_address), 0, 5)),
              (parseint(element(split(":", local.raw_segments[seg_key].mac_address), 5), 16) + index(local.sorted_node_keys, node_name)) % 256
            )
            addresses = [
              format("%s/%s",
                cidrhost(local.raw_segments[seg_key].cidr_block, node_spec.ip_suffix),
                split("/", local.raw_segments[seg_key].cidr_block)[1]
              )
            ]
            wait_for_lease = false
          }
        ]
      ])
    }
  }
}

locals {
  # Service Segments List (Infrastructure Creation)
  hydrated_service_segments = [
    for seg_key in local.sorted_segment_keys : {
      name           = seg_key
      bridge_name    = "br-${substr(replace(seg_key, "-", ""), 0, 6)}-${substr(md5("${seg_key}"), 0, 4)}"
      cidr           = local.raw_segments[seg_key].cidr_block
      nat_cidr       = local.raw_segments[seg_key].nat_cidr_block
      nat_gateway    = local.raw_segments[seg_key].nat_gateway
      vrid           = local.raw_segments[seg_key].vrid
      vip            = local.raw_segments[seg_key].vip
      interface_name = local.raw_segments[seg_key].interface_alias
      ports          = local.raw_segments[seg_key].ports
      tags           = local.raw_segments[seg_key].tags

      node_ips = {
        for node_name, node_spec in var.node_config : local.node_naming_map[node_name] =>
        cidrhost(local.raw_segments[seg_key].cidr_block, node_spec.ip_suffix)
      }
      backend_servers = [
        for i in range(
          local.raw_segments[seg_key].ip_range.end_ip - local.raw_segments[seg_key].ip_range.start_ip + 1
          ) : {
          # Name: service-slot-200, service-slot-201...
          name = "${seg_key}-slot-${local.raw_segments[seg_key].ip_range.start_ip + i}"

          ip = cidrhost(
            local.raw_segments[seg_key].cidr_block,
            local.raw_segments[seg_key].ip_range.start_ip + i
          )
        }
      ]
    }
  ]
}

locals {
  # Credentials
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  haproxy_credentials = {
    haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["haproxy_stats_pass"]
    keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["keepalived_auth_pass"]
  }
}
