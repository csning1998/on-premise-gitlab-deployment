
locals {
  sorted_node_keys = sort(keys(var.node_config))
  mac_parts        = split(":", var.svc_network.mac_address)
}

locals {
  node_interfaces = {
    for node_name, node_spec in var.node_config : node_name => concat(
      # Interface 1: NAT (Management)
      [{
        network_name = var.network_infra.nat.name
        mac = format("%s:%s:%s:00:%s:%02x",
          local.mac_parts[0],
          local.mac_parts[1],
          local.mac_parts[2],
          local.mac_parts[4],
          (parseint(local.mac_parts[5], 16) + index(local.sorted_node_keys, node_name)) % 256
        )
        addresses = []
      }],

      # Interface 2: HostOnly (Internal, carries the LB static IP)
      [{
        network_name = var.network_infra.hostonly.name
        mac = format("%s:%s:%s:%s:%s:%02x",
          local.mac_parts[0],
          local.mac_parts[1],
          local.mac_parts[2],
          local.mac_parts[3],
          local.mac_parts[4],
          (parseint(local.mac_parts[5], 16) + index(local.sorted_node_keys, node_name)) % 256
        )
        addresses = [
          format("%s/%s",
            cidrhost(var.svc_network.cidr_block, node_spec.ip_suffix),
            split("/", var.svc_network.cidr_block)[1]
          )
        ]
      }],

      # Interface 3..N: One per service segment [ens5+]
      [
        for seg_name in var.service_segment_names : {
          network_name = seg_name
          alias        = var.svc_network_map[seg_name].interface_alias
          mac = format("%s:%02x",
            join(":", slice(split(":", var.svc_network_map[seg_name].mac_address), 0, 5)),
            (parseint(element(split(":", var.svc_network_map[seg_name].mac_address), 5), 16) + index(local.sorted_node_keys, node_name)) % 256
          )
          addresses = [
            format("%s/%s",
              cidrhost(var.svc_network_map[seg_name].cidr_block, node_spec.ip_suffix),
              split("/", var.svc_network_map[seg_name].cidr_block)[1]
            )
          ]
        }
      ]
    )
  }
}

locals {
  lb_cluster_vm_config = {
    storage_pool_name = var.storage_pool_name
    nodes = {
      for node_name, node_spec in var.node_config : node_name => {
        vcpu                 = node_spec.vcpu
        ram                  = node_spec.ram
        base_image_path      = node_spec.base_image_path
        os_disk_capacity_gib = node_spec.os_disk_capacity_gib
        interfaces           = local.node_interfaces[node_name]
      }
    }
  }
}

locals {
  lb_cluster_network_config = {
    network = {
      nat = {
        name_network = var.network_infra.nat.name
        name_bridge  = var.network_infra.nat.bridge_name
        mode         = "nat"
        ips = {
          address = var.network_infra.nat.gateway
          prefix  = var.network_infra.nat.prefix
          dhcp    = var.network_infra.nat.dhcp
        }
        mtu = var.network_infra.nat.mtu
      }
      hostonly = {
        name_network = var.network_infra.hostonly.name
        name_bridge  = var.network_infra.hostonly.bridge_name
        mode         = "route"
        ips = {
          address = var.network_infra.hostonly.gateway
          prefix  = var.network_infra.hostonly.prefix
          dhcp    = null
        }
        mtu = var.network_infra.hostonly.mtu
      }
    }
  }
}

locals {
  nodes_list_for_ssh = [
    for key, node in local.lb_cluster_vm_config.nodes : {
      key = key
      ip  = split("/", node.interfaces[1].addresses[0])[0]
    }
  ]
}
