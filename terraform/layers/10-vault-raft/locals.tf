
# State Object
locals {
  state = {
    topology = data.terraform_remote_state.topology.outputs
    network  = data.terraform_remote_state.network.outputs
  }
}

# Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_identity     = local.state.topology.identity_map["${local.svc_name}-core"]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = local.svc_identity.cluster_name
}

# Network Context
locals {
  net_vault_infra = local.state.network.infrastructure_map[local.svc_name]
  net_service_vip = local.net_vault_infra.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "vault" = {
      nat_net_name         = local.net_vault_infra.network.nat.name
      nat_bridge_name      = local.net_vault_infra.network.nat.bridge_name
      hostonly_net_name    = local.net_vault_infra.network.hostonly.name
      hostonly_bridge_name = local.net_vault_infra.network.hostonly.bridge_name
    }
  }

  # Network Parameters: L3 Routing & Configuration
  network_parameters = {
    "vault" = {
      network = {
        nat = {
          gateway = local.net_vault_infra.network.nat.gateway
          cidrv4  = local.net_vault_infra.network.nat.cidr
          dhcp    = local.net_vault_infra.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_vault_infra.network.hostonly.gateway
          cidrv4  = local.net_vault_infra.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_vault_infra.network.hostonly.cidr
    }
  }
}

# Security Context
locals {
  pki_global_ca = local.state.topology.vault_pki # PKI Artifacts

  # System Level Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.vault_config
  }
}

# Node Processing & Grouping
locals {
  flat_node_map = merge([
    for comp_name, comp_data in local.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${local.svc_cluster_name}-${comp_name}-${node_suffix}" => {
        ip         = cidrhost(local.network_parameters[comp_data.network_tier].network.hostonly.cidrv4, node_data.ip_suffix)
        vcpu       = node_data.vcpu
        ram        = node_data.ram
        data_disks = node_data.data_disks

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
  primary_tier_key   = contains(keys(local.network_bindings), "default") ? "default" : keys(local.network_bindings)[0]
  primary_params     = local.network_parameters[local.primary_tier_key]
  inventory_template = "${path.module}/../../templates/${var.ansible_files.inventory_template_file}"

  ansible_inventory_content = templatefile(local.inventory_template, {

    vault_nodes = local.flat_node_map

    cluster_identity = {
      name   = local.svc_cluster_name
      domain = local.svc_fqdn
    }

    cluster_topology = {
      nodes_by_role  = local.nodes_by_role
      nodes          = local.flat_node_map
      bootstrap_node = values(local.flat_node_map)[0]
    }

    cluster_network = {
      vip          = local.net_service_vip
      nat_prefix   = join(".", slice(split(".", local.primary_params.network.nat.gateway), 0, 3))
      access_scope = local.primary_params.network_access_scope
    }
  })

  ansible_extra_vars = merge(
    {
      ansible_user = local.sec_system_creds.username
    },
    local.pki_global_ca != null && length(keys(local.pki_global_ca)) > 0 ? {
      vault_server_cert = local.pki_global_ca.server_cert
      vault_server_key  = local.pki_global_ca.server_key
      vault_ca_cert     = local.pki_global_ca.ca_cert
    } : {}
  )
}
