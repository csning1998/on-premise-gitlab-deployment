
# State Object
locals {
  state = {
    topology = data.terraform_remote_state.topology.outputs
    network  = data.terraform_remote_state.network.outputs
  }
}

# 1. Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_network_map  = local.state.topology.network_map
  svc_identity     = local.state.topology.identity_map[local.svc_name]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = local.svc_identity.cluster_name
  svc_node_prefix  = local.svc_identity.node_name_prefix
}

# 2. Network Context (delegated to 04-network-topology)
locals {
  # Deterministic Ordering
  net_sorted_node_keys = sort(keys(var.node_config))

  net_node_naming_map = {
    for idx, key in local.net_sorted_node_keys :
    key => "${local.svc_node_prefix}-${format("%02d", idx)}"
  }

  # MAC Address Derivation Base (From Layer 00 "central-lb")
  net_lb_base_mac_parts = split(":", local.svc_network_map[local.svc_name].mac_address)

  # Delegated from 04-network-topology
  net_infrastructure = local.state.network.infrastructure_map
  net_lb_config      = local.state.network.central_lb_info
  net_access_scope   = local.net_lb_config.hostonly.cidr
  net_my_segment     = local.svc_network_map[local.svc_name]
}

locals {
  # Service Segments: augment from 04 with node_ips computed here (depends on var.node_config)
  net_service_segments = [
    for seg in local.state.network.service_segments : merge(seg, {
      node_ips = {
        for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] =>
        cidrhost(local.svc_network_map[seg.name].cidr_block, node_spec.ip_suffix)
      }
    })
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

  ansible_template_vars = {
    ansible_ssh_user = local.sec_vm_creds.username
    service_domain   = local.svc_fqdn
    service_name     = local.svc_cluster_name
  }

  ansible_extra_vars = {
    terraform_runner_subnet = local.net_lb_config.hostonly.cidr
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
          network_name = local.net_lb_config.nat.name
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
          network_name = local.net_lb_config.hostonly.name
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
          for seg_key in [for seg in local.state.network.service_segments : seg.name] : {
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
