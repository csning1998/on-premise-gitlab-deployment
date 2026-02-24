
# State Object
locals {
  state = {
    topology = data.terraform_remote_state.topology.outputs
  }
}

# 1. Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_network_map  = local.state.topology.network_map
  svc_identity     = local.state.topology.identity_map["${local.svc_name}-core"]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = local.svc_identity.cluster_name
  svc_node_prefix  = local.svc_identity.node_name_prefix
}

# 2. Network Context
locals {
  # Deterministic Ordering
  net_sorted_node_keys = sort(keys(var.node_config))

  net_sorted_segment_keys = sort([
    for k, v in local.svc_network_map : k
    if k != local.svc_name
  ])

  # Centralized Bridge Naming Logic (Internal to Layer 05)
  net_bridge_naming = {
    for seg_key, seg_data in local.svc_network_map : seg_key => {
      host = "br-${substr(md5("${local.svc_name}-${seg_key}"), 0, 8)}"
      nat  = "br-${substr(md5("${local.svc_name}-${seg_key}"), 0, 8)}-nat"
    }
  }

  net_node_naming_map = {
    for idx, key in local.net_sorted_node_keys :
    key => "${local.svc_node_prefix}-${format("%02d", idx)}"
  }

  # MAC Address Derivation Base (From Layer 00 "central-lb")
  # Example: 52:54:00:0a:a4:f5 (where 0a is VRID 10)
  net_lb_base_mac_parts = split(":", local.svc_network_map[local.svc_name].mac_address)

  # Infrastructure Network Config
  net_my_segment = local.svc_network_map[local.svc_name]
}

locals {
  # Infrastructure Network Config
  net_infrastructure = {
    for seg_key, seg_data in local.svc_network_map : seg_key => {

      # 1. HostOnly Network (Internal)
      hostonly = {
        name        = seg_key
        bridge_name = local.net_bridge_naming[seg_key].host
        gateway     = cidrhost(seg_data.cidr_block, 1)
        cidr        = seg_data.cidr_block
        prefix      = tonumber(split("/", seg_data.cidr_block)[1])
      }

      # 2. Dedicated NAT Network (External)
      nat = {
        name        = "iac-${seg_key}-nat"
        bridge_name = local.net_bridge_naming[seg_key].nat
        gateway     = seg_data.nat_gateway
        cidr        = seg_data.nat_cidr_block
        prefix      = 24
        dhcp        = seg_data.nat_dhcp
      }
    }
  }
  net_access_scope = local.net_my_segment.cidr_block
  net_lb_config    = local.net_infrastructure[local.svc_name]
}

locals {
  # Service Segments List (Infrastructure Creation)
  net_service_segments = [
    for seg_key in local.net_sorted_segment_keys : {
      name           = seg_key
      bridge_name    = local.net_bridge_naming[seg_key].host
      cidr           = local.svc_network_map[seg_key].cidr_block
      nat_cidr       = local.svc_network_map[seg_key].nat_cidr_block
      nat_gateway    = local.svc_network_map[seg_key].nat_gateway
      vrid           = local.svc_network_map[seg_key].vrid
      vip            = local.svc_network_map[seg_key].vip
      interface_name = local.svc_network_map[seg_key].interface_alias
      ports          = local.svc_network_map[seg_key].ports
      tags           = local.svc_network_map[seg_key].tags

      node_ips = {
        for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] =>
        cidrhost(local.svc_network_map[seg_key].cidr_block, node_spec.ip_suffix)
      }
      backend_servers = [
        for i in range(
          local.svc_network_map[seg_key].ip_range.end_ip - local.svc_network_map[seg_key].ip_range.start_ip + 1
          ) : {
          # Name: service-slot-200, service-slot-201...
          name = "${seg_key}-slot-${local.svc_network_map[seg_key].ip_range.start_ip + i}"
          ip = cidrhost(
            local.svc_network_map[seg_key].cidr_block,
            local.svc_network_map[seg_key].ip_range.start_ip + i
          )
        }
      ]
    }
  ]
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  pki_global_ca = local.state.topology.vault_pki

  sec_vm_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  sec_haproxy_creds = {
    haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["haproxy_stats_pass"]
    keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["keepalived_auth_pass"]
  }
}

# Topology Component Construction
locals {
  # Payload Construction
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_nodes = {
    for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] => {
      vcpu            = node_spec.vcpu
      ram             = node_spec.ram
      base_image_path = var.base_image_path

      interfaces = flatten([
        # Interface 1: NAT (Management) [ens3]
        # Logic: Use Layer 00 Base MAC, but force 4th octet (VRID) to '00' for Management differentiation
        [{
          network_name = local.net_infrastructure[local.svc_name].nat.name
          mac = format("%s:%s:%s:00:%s:%02x",
            local.net_lb_base_mac_parts[0], # 52
            local.net_lb_base_mac_parts[1], # 54
            local.net_lb_base_mac_parts[2], # 00
            # 4th octet forced to 00 for NAT
            local.net_lb_base_mac_parts[4],
            (parseint(local.net_lb_base_mac_parts[5], 16) + index(local.net_sorted_node_keys, node_name)) % 256
          )
          addresses = [] # DHCP
        }],

        # Interface 2: HostOnly (Internal) [ens4]
        # Logic: Inherit Layer 00 Base MAC (VRID=10) directly + Node Index
        [{
          network_name = local.net_infrastructure[local.svc_name].hostonly.name
          mac = format("%s:%s:%s:%s:%s:%02x",
            local.net_lb_base_mac_parts[0],
            local.net_lb_base_mac_parts[1],
            local.net_lb_base_mac_parts[2],
            local.net_lb_base_mac_parts[3], # Keep VRID (e.g., 0a)
            local.net_lb_base_mac_parts[4],
            (parseint(local.net_lb_base_mac_parts[5], 16) + index(local.net_sorted_node_keys, node_name)) % 256
          )
          addresses = [
            format("%s/%s",
              cidrhost(local.net_my_segment.cidr_block, node_spec.ip_suffix),
              split("/", local.net_my_segment.cidr_block)[1]
            )
          ]
        }],

        # Interface 3..N: Service Segments [ens5...]
        # Logic: Use each Segment's Layer 00 MAC + Node Index
        [
          for seg_key in local.net_sorted_segment_keys : {
            network_name = seg_key
            alias        = local.svc_network_map[seg_key].interface_alias
            mac = format("%s:%02x",
              join(":", slice(split(":", local.svc_network_map[seg_key].mac_address), 0, 5)),
              (parseint(element(split(":", local.svc_network_map[seg_key].mac_address), 5), 16) + index(local.net_sorted_node_keys, node_name)) % 256
            )
            addresses = [
              format("%s/%s",
                cidrhost(local.svc_network_map[seg_key].cidr_block, node_spec.ip_suffix),
                split("/", local.svc_network_map[seg_key].cidr_block)[1]
              )
            ]
          }
        ]
      ])
    }
  }
}
