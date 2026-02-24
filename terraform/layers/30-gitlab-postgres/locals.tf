
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
  # gitlab-postgres falls under `${ProjectCode}-${Service}-${Component}` -> `gitlab-postgres`
  svc_postgres_identity = local.state.topology.identity_map["${local.svc_name}-postgres"]
  svc_etcd_identity     = local.state.topology.identity_map["${local.svc_name}-etcd"]
  svc_cluster_name      = local.svc_postgres_identity.cluster_name
  svc_postgres_fqdn     = local.state.topology.pki_map["${local.svc_name}-postgres-dep"].dns_san[0]
}

# Network Context
locals {
  # Lookups directly into Infrastructure Map from Layer 05
  net_postgres    = local.state.network.infrastructure_map["${local.svc_name}-postgres"]
  net_etcd        = local.state.network.infrastructure_map["${local.svc_name}-etcd"]
  net_service_vip = local.net_postgres.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "postgres" = {
      nat_net_name         = local.net_postgres.network.nat.name
      nat_bridge_name      = local.net_postgres.network.nat.bridge_name
      hostonly_net_name    = local.net_postgres.network.hostonly.name
      hostonly_bridge_name = local.net_postgres.network.hostonly.bridge_name
    }
    "etcd" = {
      nat_net_name         = local.net_etcd.network.nat.name
      nat_bridge_name      = local.net_etcd.network.nat.bridge_name
      hostonly_net_name    = local.net_etcd.network.hostonly.name
      hostonly_bridge_name = local.net_etcd.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "postgres" = {
      network = {
        nat = {
          gateway = local.net_postgres.network.nat.gateway
          cidrv4  = local.net_postgres.network.nat.cidr
          dhcp    = local.net_postgres.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_postgres.network.hostonly.gateway
          cidrv4  = local.net_postgres.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_postgres.network.hostonly.cidr
    }
    "etcd" = {
      network = {
        nat = {
          gateway = local.net_etcd.network.nat.gateway
          cidrv4  = local.net_etcd.network.nat.cidr
          dhcp    = local.net_etcd.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_etcd.network.hostonly.gateway
          cidrv4  = local.net_etcd.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_etcd.network.hostonly.cidr
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
  sec_postgres_creds = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  # Key: "${service}-${dependency}-dep" -> "gitlab-postgres-dep"
  sec_vault_identity_key = "${local.svc_name}-postgres-dep"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.dependency_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_postgres_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_postgres_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_postgres_config
  }
}

# Ansible Configuration Rendering
locals {
  # Reconstruct nodes map for Ansible Inventory rendering
  flat_node_map = merge([
    for comp_name, comp_data in var.gitlab_postgres_config : {
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

  ansible_inventory_content = templatefile("${path.module}/../../templates/${var.ansible_files.inventory_template_file}", {
    etcd_nodes     = local.nodes_by_role["etcd"]
    postgres_nodes = local.nodes_by_role["postgres"]

    cluster_identity = {
      name        = local.svc_cluster_name
      domain      = local.svc_fqdn
      common_name = local.sec_vault_agent_identity.common_name
    }
    cluster_network = {
      postgres_vip = local.net_service_vip
      vault_vip    = local.state.vault_sys.service_vip
      access_scope = local.network_parameters["postgres"].network_access_scope
      nat_prefix   = join(".", slice(split(".", local.network_parameters["postgres"].network.nat.gateway), 0, 3))
    }
  })

  ansible_extra_vars = {
    ansible_user = local.sec_system_creds.username

    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = vault_approle_auth_backend_role_secret_id.postgres_agent.secret_id
    vault_addr              = local.sys_vault_addr
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_agent_common_name = local.sec_vault_agent_identity.common_name

    pg_superuser_password   = local.sec_postgres_creds.superuser_password
    pg_replication_password = local.sec_postgres_creds.replication_password
    pg_vrrp_secret          = local.sec_postgres_creds.vrrp_secret
  }
}
