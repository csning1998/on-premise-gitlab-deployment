
locals {
  nodes_list_for_ssh = [
    for key, node in var.topology_cluster.load_balancer_config.nodes : {
      key = key
      ip  = split("/", node.interfaces[1].addresses[0])[0]
    }
  ]
}
locals {
  nodes_map_for_template = {
    for node in local.nodes_list_for_ssh : node.key => {
      ip = node.ip
    }
  }

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
}

locals {
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

locals {
  credentials_vm_for_hypervisor = {
    username            = var.credentials_vm.username
    password            = var.credentials_vm.password
    ssh_public_key_path = var.credentials_vm.ssh_public_key_path
  }

  credentials_vm_for_ssh = {
    username             = var.credentials_vm.username
    ssh_private_key_path = var.credentials_vm.ssh_private_key_path
  }

  # Secrets for HAProxy and Keepalived
  credentials_haproxy_for_ansible = {
    haproxy_stats_pass   = var.credentials_application.haproxy_stats_pass
    keepalived_auth_pass = var.credentials_application.keepalived_auth_pass
  }
}

locals {
  lb_cluster_vm_config = {
    storage_pool_name = var.topology_cluster.storage_pool_name
    nodes             = var.topology_cluster.load_balancer_config.nodes
  }

  net_my_segment = var.network_infrastructure_map[var.svc_identity.service_name]

  lb_cluster_network_config = {
    network = {
      nat = {
        name_network = local.net_my_segment.nat.name
        name_bridge  = local.net_my_segment.nat.bridge_name
        mode         = "nat"
        ips = {
          address = local.net_my_segment.nat.gateway
          prefix  = local.net_my_segment.nat.prefix
          dhcp    = local.net_my_segment.nat.dhcp
        }
      }
      hostonly = {
        name_network = local.net_my_segment.hostonly.name
        name_bridge  = local.net_my_segment.hostonly.bridge_name
        mode         = "route"
        ips = {
          address = local.net_my_segment.hostonly.gateway
          prefix  = local.net_my_segment.hostonly.prefix
          dhcp    = null
        }
      }
    }
  }
}
