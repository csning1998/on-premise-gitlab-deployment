
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
  # gitlab frontend falls under `${ProjectCode}-${Service}-${Component}` -> `gitlab-frontend`
  svc_kubeadm_identity = local.state.topology.identity_map["${local.svc_name}-frontend"]
  svc_cluster_name     = local.svc_kubeadm_identity.cluster_name
  svc_kubeadm_fqdn     = local.state.topology.pki_map["${local.svc_name}-frontend"].dns_san[0]
}

# Network Context
locals {
  # Lookups directly into Infrastructure Map from Layer 05
  net_kubeadm     = local.state.network.infrastructure_map[local.svc_name]
  net_service_vip = local.net_kubeadm.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "default" = {
      nat_net_name         = local.net_kubeadm.network.nat.name
      nat_bridge_name      = local.net_kubeadm.network.nat.bridge_name
      hostonly_net_name    = local.net_kubeadm.network.hostonly.name
      hostonly_bridge_name = local.net_kubeadm.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "default" = {
      network = {
        nat = {
          gateway = local.net_kubeadm.network.nat.gateway
          cidrv4  = local.net_kubeadm.network.nat.cidr
          dhcp    = local.net_kubeadm.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_kubeadm.network.hostonly.gateway
          cidrv4  = local.net_kubeadm.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_kubeadm.network.hostonly.cidr
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

  # Vault Agent Identity Prep
  sec_vault_identity_key = "${local.svc_name}-frontend"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_kubeadm_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_kubeadm_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_kubeadm_config
  }
}

# Ansible Configuration Rendering
locals {
  # Reconstruct nodes map for Ansible Inventory rendering
  flat_node_map = merge([
    for comp_name, comp_data in var.gitlab_kubeadm_config : {
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
    kubeadm_master_nodes = local.nodes_by_role["master"]
    kubeadm_worker_nodes = local.nodes_by_role["worker"]

    cluster_identity = {
      name = local.svc_cluster_name
    }

    cluster_network = {
      vip            = local.net_service_vip
      pod_subnet     = var.kubernetes_cluster_configuration.pod_subnet
      nat_prefix     = join(".", slice(split(".", local.network_parameters["default"].network.nat.gateway), 0, 3))
      registry_host  = local.state.topology.pki_map["harbor-frontend"].dns_san[0]
      http_nodeport  = local.net_kubeadm.lb_config.ports["ingress-http"].backend_port
      https_nodeport = local.net_kubeadm.lb_config.ports["ingress-https"].backend_port
    }
  })

  ansible_extra_vars = {
    ansible_user          = local.sec_system_creds.username
    vault_ca_cert_b64     = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id   = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
    vault_addr            = local.sys_vault_addr
    vault_role_name       = local.sec_vault_agent_identity.role_name
    service_name          = local.svc_name
  }
}
