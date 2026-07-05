
# 1. SSoT Alignment
locals {
  segments_map = merge([
    for s_name, components in var.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => {
        identity = identity
        network  = var.global_topology_network[s_name][c_name]
        pki_key  = "${s_name}-${c_name}"
        s_name   = s_name
        c_name   = c_name
      }
    }
  ]...)

  components_context = {
    for role, cluster_name in var.target_clusters : role => local.segments_map[cluster_name]
  }

  primary_context = local.components_context[var.primary_role]

  svc_identity = local.primary_context.identity
  svc_network  = local.primary_context.network
  svc_pki_role = var.global_pki_map[local.primary_context.pki_key]
  svc_fqdn     = local.svc_pki_role.dns_san[0]
}

# 2. Network Context
# The ... grouping operator handles layers where multiple roles share the same network_tier
# (e.g. kubeadm master/worker both using "default"). Taking [0] is safe: duplicate tiers
# always map to the same infrastructure config since they point to the same cluster.
locals {
  network_infrastructure_map_grouped = {
    for role, ctx in local.components_context :
    var.service_config[role].network_tier => var.infrastructure_map[ctx.identity.cluster_name]...
  }

  network_infrastructure_map = {
    for k, v in local.network_infrastructure_map_grouped : k => v[0]
  }

  primary_net_config = local.network_infrastructure_map[var.service_config[var.primary_role].network_tier]

  # Full global_topology_network entry per network_tier, exposing ports (frontend and backend)
  # and node_ips for downstream layers that need non-LB topology data such as metrics endpoints.
  # The ...[0] grouping mirrors network_infrastructure_map. duplicate tiers always resolve to the same cluster.
  tier_network_map_grouped = {
    for role, ctx in local.components_context :
    var.service_config[role].network_tier => ctx.network...
  }

  tier_network_map = {
    for k, v in local.tier_network_map_grouped : k => v[0]
  }
}

# 3. Security & Credentials
locals {
  sys_vault_endpoint = var.vault_sys_vip != null ? "https://${var.vault_sys_vip}:443" : null

  sec_vm_credentials = {
    username             = var.guest_vm_data["vm_username"]
    password             = var.guest_vm_data["vm_password"]
    ssh_public_key_path  = var.guest_vm_data["ssh_public_key_path"]
    ssh_private_key_path = var.guest_vm_data["ssh_private_key_path"]
  }
}

# 4. Topology
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.service_config
    storage_pool_name = local.storage_pool_name
  }

  node_identities = {
    for role, ctx in local.components_context : role => ctx.identity
  }
}

# 5. Vault Agent Identities (partial — secret_id must be injected by root module after AppRole generation)
# vault_pki_outputs absent (Layer 15 and earlier) → all_vault_agent_identity_bases = {}, vault_agent_identity_base = null
locals {
  all_vault_agent_identity_bases = var.vault_pki_outputs != null ? {
    for role, ctx in local.components_context : role => {
      vault_endpoint = local.sys_vault_endpoint
      auth_path      = var.vault_pki_outputs.workload_identities_approle[var.global_pki_map[ctx.pki_key].key].auth_path
      role_id        = var.vault_pki_outputs.workload_identities_approle[var.global_pki_map[ctx.pki_key].key].role_id
      role_name      = var.vault_pki_outputs.pki_configuration.pki_roles[var.global_pki_map[ctx.pki_key].key].name
      ca_cert_b64    = var.vault_pki_outputs.bootstrap_ca_b64.content_b64
      common_name    = var.global_pki_map[ctx.pki_key].dns_san[0]
    }
  } : {}

  vault_agent_identity_base = lookup(local.all_vault_agent_identity_bases, var.primary_role, null)
}

# 6. Asymmetric Static Routes
# Keyed by network_tier so each tier uses its own LB VIP as gateway (on-link requirement).
# '...' grouping deduplicates tiers shared across roles (e.g. kubeadm master/worker); [0] is safe.
locals {
  all_cluster_net_specs = flatten([
    for s_name, components in var.global_topology_network : [
      for c_name, net in components : {
        s_name = s_name
        c_name = c_name
        cidrs = concat(
          [net.cidr_block],
          contains(["microk8s", "kubeadm"], net.runtime) ? [net.nat_cidr_block] : []
        )
      }
    ]
  ])
}

locals {
  asymmetric_static_routes_grouped = {
    for role, ctx in local.components_context :
    var.service_config[role].network_tier => flatten([
      for spec in local.all_cluster_net_specs :
      (spec.s_name != ctx.s_name || spec.c_name != ctx.c_name) ? [
        for cidr in spec.cidrs : {
          to     = cidr
          via    = local.network_infrastructure_map[var.service_config[role].network_tier].lb_config.vip
          metric = 100
        }
      ] : []
    ])...
  }

  asymmetric_static_routes = {
    for k, v in local.asymmetric_static_routes_grouped : k => v[0]
  }
}
