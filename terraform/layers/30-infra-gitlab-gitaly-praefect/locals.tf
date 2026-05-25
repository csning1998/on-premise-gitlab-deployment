
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs # Source from `00-foundation-metadata`
    volume    = data.terraform_remote_state.volume.outputs   # Source from `05-foundation-volume`
    network   = data.terraform_remote_state.network.outputs  # Source from `10-shared-load-balancer-frontend`
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
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

  # Resolve all components statically from the SSoT to prevent key errors in progressive deployment
  components_context = {
    "gitaly"           = local.segments_map["core-gitlab-gitaly"]
    "praefect"         = local.segments_map["core-gitlab-praefect"]
    "praefect-patroni" = local.segments_map["core-gitlab-praefect-patroni"]
  }

  primary_role    = var.primary_role
  primary_context = local.components_context[local.primary_role]

  svc_identity = local.primary_context.identity
  svc_network  = local.primary_context.network
}

# 2. Network Context (Inherit from Load Balancer Handover)
locals {
  # Map physical networks for all components into an infrastructure map for middleware
  network_infrastructure_map = {
    for role, ctx in local.components_context : var.service_config[role].network_tier => local.state.network.infrastructure_map[ctx.identity.cluster_name]
    if lookup(var.service_config, role, null) != null
  }

  # Helper for primary network configuration to reduce path redundancy
  p_net_config = local.network_infrastructure_map[var.service_config[local.primary_role].network_tier]
}

# 3. Security & Credentials Context (sec_ / pki_ / sys_)
locals {
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

  # System Level Credentials (OS/SSH)
  sec_vm_creds = {
    username             = data.vault_generic_secret.guest_vm.data["vm_username"]
    password             = data.vault_generic_secret.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.guest_vm.data["ssh_private_key_path"]
  }

  # Service Specific Credentials (DB/PG/Gitaly)
  sec_app_creds = {
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # Dynamic Vault Agent AppRole Identity Generation per component
  role_vault_agent_identities = {
    for role, ctx in local.components_context : role => {
      vault_address = local.sys_vault_addr
      auth_path     = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[ctx.pki_key].key].auth_path
      role_id       = local.state.vault_pki.workload_identities_approle[local.state.metadata.global_pki_map[ctx.pki_key].key].role_id
      role_name     = local.state.vault_pki.pki_configuration.pki_roles[local.state.metadata.global_pki_map[ctx.pki_key].key].name
      secret_id     = vault_approle_auth_backend_role_secret_id.component_agents[role].secret_id
      ca_cert_b64   = local.state.vault_pki.bootstrap_ca_b64.content_b64
      common_name   = local.state.metadata.global_pki_map[ctx.pki_key].dns_san[0]
    }
    if contains(keys(var.target_clusters), role)
  }

  sec_vault_agent_identity = local.role_vault_agent_identities[local.primary_role]
}

# 4. Topology & Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.service_config
    storage_pool_name = local.storage_pool_name
  }

  # Map logical roles to their respective physical identities from SSoT
  node_identities = {
    for role, ctx in local.components_context : role => ctx.identity
  }
}

# 5. Ansible Configuration (Dynamic Inventory)
locals {
  # Generate standard template variables passed to Ansible.
  # Construct a composite map containing all information required by Gitaly, Praefect, and Patroni roles.
  ansible_template_vars = {
    # Service Identifiers
    service_identifier    = local.svc_identity.cluster_name
    postgres_cluster_name = lookup(var.target_clusters, "praefect-patroni", "") != "" ? var.target_clusters["praefect-patroni"] : ""

    # Networking & HA for database
    postgres_ha_virtual_ip = lookup(local.network_infrastructure_map, "praefect-patroni", null) != null ? local.network_infrastructure_map["praefect-patroni"].lb_config.vip : ""
    postgres_mtls_node_subnet = join(" ", compact([
      lookup(local.network_infrastructure_map, "praefect-patroni", null) != null ? local.network_infrastructure_map["praefect-patroni"].network.hostonly.cidr : "",
      lookup(local.network_infrastructure_map, "praefect", null) != null ? local.network_infrastructure_map["praefect"].network.hostonly.cidr : "",
      local.state.network.infrastructure_map["core-gitlab-frontend"].network.hostonly.cidr,
    ]))
    vault_vip  = local.state.vault_sys.service_vip
    global_mss = local.state.metadata.global_network_baseline.global_mss

    # Gitaly and Praefect HA
    gitaly_ha_virtual_ip   = lookup(local.network_infrastructure_map, "gitaly", null) != null ? local.network_infrastructure_map["gitaly"].lb_config.vip : ""
    praefect_ha_virtual_ip = lookup(local.network_infrastructure_map, "praefect", null) != null ? local.network_infrastructure_map["praefect"].lb_config.vip : ""
    gitlab_frontend_vip    = lookup(local.state.network.infrastructure_map, "core-gitlab-frontend", null) != null ? local.state.network.infrastructure_map["core-gitlab-frontend"].lb_config.vip : ""

    # Asymmetric Routing Lists (Native HCL list of objects, matching harbor style)
    gitaly_static_routes = [
      for name, vip in local.state.network.infrastructure_vips : {
        to     = "${vip}/32"
        via    = lookup(local.network_infrastructure_map, "gitaly", null) != null ? local.network_infrastructure_map["gitaly"].lb_config.vip : ""
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-frontend", "gitlab-praefect"], name)
    ]

    praefect_static_routes = [
      for name, vip in local.state.network.infrastructure_vips : {
        to     = "${vip}/32"
        via    = lookup(local.network_infrastructure_map, "praefect", null) != null ? local.network_infrastructure_map["praefect"].lb_config.vip : ""
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-frontend", "gitlab-gitaly", "gitlab-praefect-patroni"], name)
    ]

    postgres_static_routes = [
      for name, vip in local.state.network.infrastructure_vips : {
        to     = "${vip}/32"
        via    = lookup(local.network_infrastructure_map, "praefect-patroni", null) != null ? local.network_infrastructure_map["praefect-patroni"].lb_config.vip : ""
        metric = 100
      }
      if contains(["vault-frontend", "gitlab-praefect"], name)
    ]

    # Tell 30-infra-postgres role which key to look up inside vault_agent_identities_json.
    # The middleware injects the primary role's (praefect) identity as flat vars for all nodes;
    # this key lets praefect-patroni nodes override those with their own identity.
    postgres_vault_role_key = "praefect-patroni"
  }

  ansible_extra_vars = {
    gitlab_external_url     = "https://${local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]}"
    gitlab_shell_secret     = random_password.gitlab_shell_secret.result
    gitaly_auth_token       = random_password.gitaly_token.result
    praefect_external_token = one(random_password.praefect_external_token[*].result)
    praefect_db_password    = one(random_password.praefect_db_password[*].result)
    pg_replication_password = random_password.pg_replication_password.result
    pg_superuser_password   = random_password.pg_superuser_password.result
    pg_vrrp_secret          = random_password.pg_vrrp_secret.result
    vault_agent_cert_ttl    = tostring(local.state.vault_pki.pki_configuration.lease_durations.agent)

    # Base64-encoded JSON of per-component Vault AppRole credentials (sensitive).
    # Encoding avoids shell quoting issues: ansible provider passes extra_vars via bare
    # `-e key=value`; raw JSON with `{}` and `:` gets misinterpreted as a playbook path.
    # Ansible roles decode with `| b64decode | from_json`.
    vault_agent_identities_json = base64encode(jsonencode({
      for role, id in local.role_vault_agent_identities : role => {
        vault_addr  = id.vault_address
        role_id     = id.role_id
        secret_id   = id.secret_id
        role_name   = id.role_name
        auth_path   = id.auth_path
        common_name = id.common_name
      }
    }))
  }
}
