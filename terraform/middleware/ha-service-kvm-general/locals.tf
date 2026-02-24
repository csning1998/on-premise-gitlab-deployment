
# Node Processing & Grouping
locals {
  flat_node_map = merge([
    for comp_name, comp_data in var.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${var.cluster_name}-${comp_name}-${node_suffix}" => {
        # The Fundamental Specifications are Inherited from Node.
        ip         = cidrhost(var.network_parameters[comp_data.network_tier].network.hostonly.cidrv4, node_data.ip_suffix)
        vcpu       = node_data.vcpu
        ram        = node_data.ram
        data_disks = node_data.data_disks

        # The Component Level Specifications are Inherited from Component.
        base_image_path = comp_data.base_image_path
        role            = comp_data.role
        network_tier    = comp_data.network_tier
      }
    }
  ]...)

  vm_config = {
    all_nodes_map = {
      for k, v in local.flat_node_map : k => {
        ip              = v.ip
        vcpu            = v.vcpu
        ram             = v.ram
        base_image_path = v.base_image_path
        data_disks      = v.data_disks
        network_tier    = v.network_tier
      }
    }
  }
}

# Ansible Configuration
locals {
  ansible = {
    root_path      = abspath("${path.module}/../../../ansible")
    playbook_file  = "playbooks/${var.ansible_playbook_file}"
    inventory_file = "inventory-${var.cluster_name}.yaml"
  }
}

# Security Credentials
locals {
  vm_credentials_for_hypervisor = {
    username            = var.credentials_system.username
    password            = var.credentials_system.password
    ssh_public_key_path = var.credentials_system.ssh_public_key_path
  }

  vm_credentials_for_ssh = {
    username             = var.credentials_system.username
    ssh_private_key_path = var.credentials_system.ssh_private_key_path
  }
}

# Primary Tier Selection for KVM Module Undeclared local value
locals {
  primary_tier_key = contains(keys(var.network_bindings), "default") ? "default" : keys(var.network_bindings)[0]
  primary_params   = var.network_parameters[local.primary_tier_key]
}

# KVM Module Adaptation (Interface Translation)
locals {
  hypervisor_kvm_infrastructure = {
    for tier, binding in var.network_bindings : tier => {
      network = {
        nat = {
          name_network = binding.nat_net_name
          name_bridge  = binding.nat_bridge_name
          mode         = "nat"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.nat.cidrv4)[1])
            address = var.network_parameters[tier].network.nat.gateway
            dhcp    = var.network_parameters[tier].network.nat.dhcp
          }
        }
        hostonly = {
          name_network = binding.hostonly_net_name
          name_bridge  = binding.hostonly_bridge_name
          mode         = "route"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.hostonly.cidrv4)[1])
            address = var.network_parameters[tier].network.hostonly.gateway
            dhcp    = null
          }
        }
      }
      storage_pool_name = var.topology_cluster.storage_pool_name
    }
  }
}
