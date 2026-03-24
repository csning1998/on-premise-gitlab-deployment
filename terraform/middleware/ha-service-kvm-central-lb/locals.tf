
locals {
  # 1. Credentials Context
  credentials_vm_for_hypervisor = var.credentials_vm
  credentials_vm_for_ssh = {
    username             = var.credentials_vm.username
    ssh_private_key_path = var.credentials_vm.ssh_private_key_path
  }
  credentials_haproxy_for_ansible = {
    haproxy_stats_pass   = var.credentials_application.haproxy_stats_pass
    keepalived_auth_pass = var.credentials_application.keepalived_auth_pass
  }

  # 2. Physics & Network Context
  net_lb_base_mac_parts = split(":", var.svc_network_map[var.svc_identity.service_name].mac_address)
  net_sorted_node_keys  = sort(keys(var.topology_cluster.load_balancer_config.nodes))

  lb_cluster_vm_config = {
    storage_pool_name = var.topology_cluster.storage_pool_name
    nodes = {
      for node_name, node_spec in var.topology_cluster.load_balancer_config.nodes : node_name => {
        vcpu            = node_spec.vcpu
        ram             = node_spec.ram
        base_image_path = node_spec.base_image_path

        interfaces = flatten([
          # Interface 1: NAT (Management) [ens3]
          [{
            network_name = var.network_infrastructure_map[var.svc_identity.service_name].nat.name
            mac = format("%s:%s:%s:00:%s:%02x",
              local.net_lb_base_mac_parts[0],
              local.net_lb_base_mac_parts[1],
              local.net_lb_base_mac_parts[2],
              local.net_lb_base_mac_parts[4],
              (parseint(local.net_lb_base_mac_parts[5], 16) + index(local.net_sorted_node_keys, node_name)) % 256
            )
            addresses = []
          }],

          # Interface 2: HostOnly (Internal) [ens4]
          [{
            network_name = var.network_infrastructure_map[var.svc_identity.service_name].hostonly.name
            mac = format("%s:%s:%s:%s:%s:%02x",
              local.net_lb_base_mac_parts[0],
              local.net_lb_base_mac_parts[1],
              local.net_lb_base_mac_parts[2],
              local.net_lb_base_mac_parts[3],
              local.net_lb_base_mac_parts[4],
              (parseint(local.net_lb_base_mac_parts[5], 16) + index(local.net_sorted_node_keys, node_name)) % 256
            )
            addresses = [
              format("%s/%s",
                cidrhost(var.svc_network_map[var.svc_identity.service_name].cidr_block, node_spec.ip_suffix),
                split("/", var.svc_network_map[var.svc_identity.service_name].cidr_block)[1]
              )
            ]
          }],

          # Interface 3..N: Service Segments [ens5...]
          [
            for seg in var.network_service_segments : {
              network_name = seg.name
              alias        = var.svc_network_map[seg.name].interface_alias
              mac = format("%s:%02x",
                join(":", slice(split(":", var.svc_network_map[seg.name].mac_address), 0, 5)),
                (parseint(element(split(":", var.svc_network_map[seg.name].mac_address), 5), 16) + index(local.net_sorted_node_keys, node_name)) % 256
              )
              addresses = [
                format("%s/%s",
                  cidrhost(var.svc_network_map[seg.name].cidr_block, node_spec.ip_suffix),
                  split("/", var.svc_network_map[seg.name].cidr_block)[1]
                )
              ]
            }
          ]
        ])
      }
    }
  }

  lb_cluster_network_config = {
    network = {
      nat = {
        name_network = var.network_infrastructure_map[var.svc_identity.service_name].nat.name
        name_bridge  = var.network_infrastructure_map[var.svc_identity.service_name].nat.bridge_name
        mode         = "nat"
        ips = {
          address = var.network_infrastructure_map[var.svc_identity.service_name].nat.gateway
          prefix  = var.network_infrastructure_map[var.svc_identity.service_name].nat.prefix
          dhcp    = var.network_infrastructure_map[var.svc_identity.service_name].nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_infrastructure_map[var.svc_identity.service_name].hostonly.name
        name_bridge  = var.network_infrastructure_map[var.svc_identity.service_name].hostonly.bridge_name
        mode         = "route"
        ips = {
          address = var.network_infrastructure_map[var.svc_identity.service_name].hostonly.gateway
          prefix  = var.network_infrastructure_map[var.svc_identity.service_name].hostonly.prefix
          dhcp    = null
        }
      }
    }
  }

  # 3. Connectivity Context
  nodes_list_for_ssh = [
    for key, node in local.lb_cluster_vm_config.nodes : {
      key = key
      # HostOnly Interface is assumed to be the 2nd interface [ens4]
      ip = split("/", node["interfaces"][1].addresses[0])[0]
    }
  ]

  nodes_map_for_template = {
    for node in local.nodes_list_for_ssh : node.key => {
      ip = node.ip
    }
  }

  # 4. Ansible & Orchestration Context
  ansible = {
    root_path          = abspath("${path.module}/../../../ansible")
    playbook_file      = "playbooks/${var.ansible_playbook_file}"
    inventory_file     = var.svc_identity.ansible_inventory
    inventory_template = "${path.module}/../../templates/${var.ansible_inventory_template_file}"

    inventory_contents = templatefile("${path.module}/../../templates/${var.ansible_inventory_template_file}", merge(var.ansible_template_vars, {
      load_balancer_nodes = local.nodes_map_for_template
      service_segments    = var.network_service_segments
    }))
  }

  ansible_extra_vars = merge(
    var.ansible_extra_vars,
    {
      haproxy_stats_pass   = local.credentials_haproxy_for_ansible.haproxy_stats_pass
      keepalived_auth_pass = local.credentials_haproxy_for_ansible.keepalived_auth_pass
    },
    var.security_pki_bundle != null ? {
      vault_haproxy_bundle = var.security_pki_bundle.haproxy_bundle
      vault_ca_cert        = var.security_pki_bundle.ca_cert
    } : {}
  )
}
