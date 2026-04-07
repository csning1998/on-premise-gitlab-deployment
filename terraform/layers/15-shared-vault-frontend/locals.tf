
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
    volume   = data.terraform_remote_state.volume.outputs
    network  = data.terraform_remote_state.network.outputs # Handover through Layer 10
  }
}

# 1. Unified SSoT Alignment
locals {
  # Zip Identity and Network properties into a single O(1) lookup map.
  segments_map = merge([
    for s_name, components in local.state.metadata.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = local.state.metadata.global_topology_network[s_name][c_name]
        pki_key  = "${s_name}-${c_name}"
        s_name   = s_name
        c_name   = c_name
      }
    }
  ]...)

  # Target the cluster using the unified SSoT key passed via tfvars
  svc_cluster_name = var.target_cluster_name
  svc_context      = local.segments_map[local.svc_cluster_name]

  svc_identity = local.svc_context.identity
  svc_network  = local.svc_context.network

  # Fetch DNS from PKI metadata (mapped by s_name-c_name)
  svc_pki_role = local.state.metadata.global_pki_map[local.svc_context.pki_key]
  svc_fqdn     = local.svc_pki_role.dns_san[0]
}

# 2. Network Context (Inherit from Load Balancer Handover)
locals {
  # Layer 10 (network state) provides infrastructure_map keyed by cluster_name
  net_physical_infra = local.state.network.infrastructure_map[local.svc_cluster_name]

  # Single map of raw infrastructures for KVM (module consumption)
  # Act as an adapter, mapping the true physical network to the generic "default" tier.
  network_infrastructure_map = {
    "default" = local.net_physical_infra
  }
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  pki_global_ca = local.state.metadata.global_vault_pki # PKI Artifacts

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_kv_secret_v2.guest_vm.data["vm_username"]
    password             = data.vault_kv_secret_v2.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_kv_secret_v2.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_kv_secret_v2.guest_vm.data["ssh_private_key_path"]
  }
}

# 4. Topology & Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.vault_config
    storage_pool_name = local.storage_pool_name
  }

  # Map dynamic component names back to their single physical identity
  node_identities = {
    for comp_name, comp_config in var.vault_config : comp_name => local.svc_identity
  }
}

# 5. Ansible Configuration (Dynamic Inventory)
locals {
  ansible_template_vars = {
    vault_vip = local.net_physical_infra.lb_config.vip
  }

  ansible_extra_vars = merge(
    {
      ansible_user       = local.sec_vm_creds.username
      dev_vault_url      = var.vault_dev_addr
      dev_vault_api_path = "on-premise-gitlab-deployment/credentials"
    },
    local.pki_global_ca != null && length(keys(local.pki_global_ca)) > 0 ? {
      vault_server_cert = local.pki_global_ca.server_cert
      vault_server_key  = local.pki_global_ca.server_key
      vault_ca_cert     = local.pki_global_ca.ca_cert
    } : {}
  )
}
