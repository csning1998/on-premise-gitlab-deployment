
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

  # Group nodes by role for Ansible Inventory
  nodes_by_role = {
    for role in distinct(values(local.flat_node_map).*.role) : role => {
      for name, node in local.flat_node_map : name => node
      if node.role == role
    }
  }
}

# Ansible Configuration (Dynamic Inventory)
locals {
  inventory_template        = "${path.module}/../../../templates/${var.ansible_files.inventory_template_file}"
  primary_tier_key          = contains(keys(var.network_bindings), "default") ? "default" : keys(var.network_bindings)[0]
  primary_params            = var.network_parameters[local.primary_tier_key]
  nat_network_subnet_prefix = join(".", slice(split(".", local.primary_params.network.nat.gateway), 0, 3))

  ansible = {
    root_path      = abspath("${path.module}/../../../../ansible")
    playbook_file  = "playbooks/${var.ansible_files.playbook_file}"
    inventory_file = "inventory-${var.cluster_name}.yaml"

    inventory_contents = templatefile(local.inventory_template, {

      ansible_ssh_user = var.credentials_system.username
      service_name     = split("-", var.cluster_name)[1]

      microk8s_nodes = local.flat_node_map

      # Network information
      microk8s_ingress_vip       = var.service_vip
      microk8s_allowed_subnet    = local.primary_params.network_access_scope
      microk8s_nat_subnet_prefix = local.nat_network_subnet_prefix
    })
  }

  ansible_extra_vars = {}
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

# KVM Module Adaptation (Interface Translation)
# - Convert input bindings/params into KVM Module's expected Map structure
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
