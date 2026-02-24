
# State Object
locals {
  state = {
    topology  = data.terraform_remote_state.topology.outputs
    network   = data.terraform_remote_state.network.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
  }
}

# Service Context
locals {
  svc_name = var.service_catalog_name
  svc_fqdn = local.state.topology.domain_suffix

  # Using the standardized keys logic from Layer 00 naming map
  svc_minio_identity = local.state.topology.identity_map["${local.svc_name}-minio"]
  svc_cluster_name   = local.svc_minio_identity.cluster_name
  svc_minio_fqdn     = local.state.topology.pki_map["${local.svc_name}-minio-dep"].dns_san[0]
}

# Network Context
locals {
  # Lookups directly into Infrastructure Map from Layer 05
  net_minio       = local.state.network.infrastructure_map["${local.svc_name}-minio"]
  net_service_vip = local.net_minio.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "minio" = {
      nat_net_name         = local.net_minio.network.nat.name
      nat_bridge_name      = local.net_minio.network.nat.bridge_name
      hostonly_net_name    = local.net_minio.network.hostonly.name
      hostonly_bridge_name = local.net_minio.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "minio" = {
      network = {
        nat = {
          gateway = local.net_minio.network.nat.gateway
          cidrv4  = local.net_minio.network.nat.cidr
          dhcp    = local.net_minio.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_minio.network.hostonly.gateway
          cidrv4  = local.net_minio.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_minio.network.hostonly.cidr
    }
  }
}

# Security & App Context
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_vault_ca_b64 = local.state.topology.vault_pki.ca_cert

  # System Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Database Credentials (Patroni/Replication)
  sec_db_creds = {
    minio_root_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
    minio_root_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
    minio_vrrp_secret   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  sec_vault_identity_key = "${local.svc_name}-minio-dep"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.dependency_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_minio_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_minio_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_minio_config
  }
}

# Ansible Configuration Rendering
locals {
  # Reconstruct nodes map for Ansible Inventory rendering
  flat_node_map = merge([
    for comp_name, comp_data in var.gitlab_minio_config : {
      for node_suffix, node_data in comp_data.nodes :
      "${local.svc_cluster_name}-${comp_name}-${node_suffix}" => {
        ip   = cidrhost(local.network_parameters[comp_data.network_tier].network.hostonly.cidrv4, node_data.ip_suffix)
        role = comp_data.role
      }
    }
  ]...)

  nodes_by_role = {
    for role in distinct(values(local.flat_node_map).*.role) : role => {
      for name, node in local.flat_node_map : name => node
      if node.role == role
    }
  }

  ansible_inventory_content = templatefile("${path.module}/../../templates/inventory-minio-cluster.yaml.tftpl", {
    minio_nodes = local.nodes_by_role["minio"]

    cluster_identity = {
      name        = local.svc_cluster_name
      domain      = local.svc_minio_fqdn
      common_name = local.sec_vault_agent_identity.common_name
    }

    cluster_network = {
      minio_vip             = local.net_service_vip
      vault_vip             = regex("://([^:]+)", local.sys_vault_addr)[0]
      access_scope          = local.network_parameters["minio"].network_access_scope
      api_frontend_port     = local.net_minio.lb_config.ports["api"].frontend_port
      console_frontend_port = local.net_minio.lb_config.ports["console"].frontend_port
      nat_prefix            = join(".", slice(split(".", local.network_parameters["minio"].network.nat.gateway), 0, 3))
    }
  })

  ansible_extra_vars = {
    ansible_user            = local.sec_system_creds.username
    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = vault_approle_auth_backend_role_secret_id.minio_agent.secret_id
    vault_addr              = local.sys_vault_addr
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    minio_root_user         = local.sec_db_creds.minio_root_user
    minio_root_password     = local.sec_db_creds.minio_root_password
    minio_vrrp_secret       = local.sec_db_creds.minio_vrrp_secret
  }
}
