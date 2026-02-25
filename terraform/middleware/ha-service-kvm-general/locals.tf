
# Node Processing & Grouping
locals {
  flat_node_map = merge([
    for comp_name, comp_data in var.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${var.node_identities[comp_name].node_name_prefix}-${node_suffix}" => {
        # The Fundamental Specifications are Inherited from Node.
        ip         = cidrhost(var.network_infrastructure_map[comp_data.network_tier].network.hostonly.cidr, node_data.ip_suffix)
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

  nodes_by_role = {
    for role in distinct(values(local.flat_node_map).*.role) : role => {
      for name, node in local.flat_node_map : name => node
      if node.role == role
    }
  }

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
    inventory_file = var.svc_identity.ansible_inventory
  }

  ansible_inventory_content = templatefile("${path.module}/../../templates/${var.ansible_inventory_template_file}", {
    nodes_by_role    = local.nodes_by_role
    all_nodes        = local.flat_node_map
    cluster_identity = var.svc_identity
    custom_vars      = var.ansible_template_vars
  })

  ansible_extra_vars_base = {
    ansible_user = var.credentials_system.username
  }

  ansible_extra_vars_vault = var.security_vault_agent_identity != null ? {
    vault_addr              = var.security_vault_agent_identity.vault_address
    vault_ca_cert_b64       = var.security_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = var.security_vault_agent_identity.role_id
    vault_agent_secret_id   = var.security_vault_agent_identity.secret_id
    vault_role_name         = var.security_vault_agent_identity.role_name
    vault_agent_common_name = var.security_vault_agent_identity.common_name
  } : {}

  ansible_extra_vars_pki = var.security_pki_bundle != null && length(keys(var.security_pki_bundle)) > 0 ? {
    vault_server_cert = var.security_pki_bundle.server_cert
    vault_server_key  = var.security_pki_bundle.server_key
    vault_ca_cert     = var.security_pki_bundle.ca_cert
  } : {}

  ansible_extra_vars = merge(
    local.ansible_extra_vars_base,
    local.ansible_extra_vars_vault,
    local.ansible_extra_vars_pki,
    var.ansible_extra_vars
  )
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

# Primary Tier Selection
locals {
  primary_tier_key = contains(keys(var.network_infrastructure_map), "default") ? "default" : keys(var.network_infrastructure_map)[0]
  primary_params   = var.network_infrastructure_map[local.primary_tier_key]
}

# KVM Module Adaptation (Interface Translation)
locals {
  hypervisor_kvm_infrastructure = {
    for tier, infra in var.network_infrastructure_map : tier => {
      network = {
        nat = {
          name_network = infra.network.nat.name
          name_bridge  = infra.network.nat.bridge_name
          mode         = "nat"
          ips = {
            prefix  = tonumber(split("/", infra.network.nat.cidr)[1])
            address = infra.network.nat.gateway
            dhcp    = infra.network.nat.dhcp
          }
        }
        hostonly = {
          name_network = infra.network.hostonly.name
          name_bridge  = infra.network.hostonly.bridge_name
          mode         = "route"
          ips = {
            prefix  = tonumber(split("/", infra.network.hostonly.cidr)[1])
            address = infra.network.hostonly.gateway
            dhcp    = null
          }
        }
      }
      storage_pool_name = var.topology_cluster.storage_pool_name
    }
  }
}
