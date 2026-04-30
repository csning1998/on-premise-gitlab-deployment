
locals {
  # 0. Global Alias
  svc_name = var.svc_identity.service_name
  svc_net  = var.svc_network_map[local.svc_name]
  infra    = var.network_infrastructure_map[local.svc_name]

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
  net_lb_base_mac_parts = split(":", local.svc_net.mac_address)
  net_sorted_node_keys  = sort(keys(var.topology_cluster.load_balancer_config.nodes))

  lb_cluster_vm_config = {
    storage_pool_name = var.topology_cluster.storage_pool_name
    nodes = {
      for node_name, node_spec in var.topology_cluster.load_balancer_config.nodes : node_name => {
        vcpu            = node_spec.vcpu
        ram             = node_spec.ram
        base_image_path = node_spec.base_image_path

        interfaces = flatten([
          # Interface 1: NAT (Management)
          [{
            network_name = local.infra.nat.name
            mac = format("%s:%s:%s:00:%s:%02x",
              local.net_lb_base_mac_parts[0],
              local.net_lb_base_mac_parts[1],
              local.net_lb_base_mac_parts[2],
              local.net_lb_base_mac_parts[4],
              (parseint(local.net_lb_base_mac_parts[5], 16) + index(local.net_sorted_node_keys, node_name)) % 256
            )
            addresses = []
          }],

          # Interface 2: HostOnly (Internal)
          [{
            network_name = local.infra.hostonly.name
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
                cidrhost(local.svc_net.cidr_block, node_spec.ip_suffix),
                split("/", local.svc_net.cidr_block)[1]
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
        name_network = local.infra.nat.name
        name_bridge  = local.infra.nat.bridge_name
        mode         = "nat"
        ips = {
          address = local.infra.nat.gateway
          prefix  = local.infra.nat.prefix
          dhcp    = local.infra.nat.dhcp
        }
        mtu = local.infra.nat.mtu
      }
      hostonly = {
        name_network = local.infra.hostonly.name
        name_bridge  = local.infra.hostonly.bridge_name
        mode         = "route"
        ips = {
          address = local.infra.hostonly.gateway
          prefix  = local.infra.hostonly.prefix
          dhcp    = null
        }
        mtu = local.infra.hostonly.mtu
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
    root_path      = abspath("${path.module}/../../../ansible")
    inventory_file = var.svc_identity.ansible_inventory
  }

  ansible_inventory_data = {
    all = {
      vars = merge(
        var.ansible_generic_config.template_vars,
        {
          service_identifier = var.svc_identity.service_name
          service_domain     = var.svc_identity.domain_suffix

          lb_service_segments = [
            for seg in var.network_service_segments : {
              name            = seg.name
              vip             = seg.vip
              cidr            = seg.cidr
              vrid            = seg.vrid
              interface_alias = seg.interface_name
              ports = {
                for p_key, p_val in seg.ports : p_key => {
                  frontend                 = p_val.frontend_port
                  backend                  = p_val.backend_port
                  health_check_type        = p_val.health_check_type
                  health_check_http_path   = p_val.health_check_http_path
                  health_check_http_expect = p_val.health_check_http_expect
                  health_check_ssl         = p_val.health_check_ssl
                  health_check_port        = p_val.health_check_port
                  send_proxy_v2            = p_val.send_proxy_v2
                }
              }
              tags = seg.tags
              backend_servers = [
                for srv in seg.backend_servers : {
                  name = srv.name
                  ip   = srv.ip
                }
              ]
            }
          ]
        }
      )

      children = {
        lb = {
          hosts = {
            for name, node in local.lb_cluster_vm_config.nodes : name => {
              ansible_host = split("/", node["interfaces"][1].addresses[0])[0]
              advertise_ip = split("/", node["interfaces"][1].addresses[0])[0]
              node_id      = name
              node_role    = "load_balancer"
              service_ips = {
                for seg in var.network_service_segments : seg.name => seg.node_ips[name]
              }
            }
          }
        }
      }
    }
  }

  ansible_extra_vars = merge(
    var.ansible_generic_config.extra_vars,
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
