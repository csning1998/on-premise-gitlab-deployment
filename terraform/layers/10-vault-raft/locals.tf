
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
  svc_raft_comp    = local.state.topology.service_structure[local.svc_name].components["raft"]
  svc_identity     = local.svc_raft_comp.identity
  svc_fqdn         = local.svc_raft_comp.role.dns_san[0]
  svc_cluster_name = local.svc_identity.cluster_name
}

# Network Context
locals {
  net_vault_infra = local.state.network.infrastructure_map[local.state.topology.service_structure[local.svc_name].network.segment_key]
  net_service_vip = local.net_vault_infra.lb_config.vip

  # Single map of raw infrastructures for KVM
  network_infrastructure_map = {
    vault = local.net_vault_infra
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

  node_identities = {
    "vault" = local.svc_identity
  }
}

# Node Processing & Grouping
locals {
  flat_node_map = merge([
    for comp_name, comp_data in local.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${local.svc_identity.node_name_prefix}-${node_suffix}" => {
        ip         = cidrhost(local.network_infrastructure_map[comp_data.network_tier].network.hostonly.cidr, node_data.ip_suffix)
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
  ansible_template_vars = {
    vault_vip = local.net_service_vip
  }

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
