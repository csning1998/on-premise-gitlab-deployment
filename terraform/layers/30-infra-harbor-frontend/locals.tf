
# State Object
locals {
  state = {
    metadata  = data.terraform_remote_state.metadata.outputs
    volume    = data.terraform_remote_state.volume.outputs
    network   = data.terraform_remote_state.load_balancer.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
  }
}

# Service Context
locals {
  primary_role    = var.primary_role
  segments_map    = local.state.metadata.global_topology_network["harbor"]
  primary_segment = local.segments_map["frontend"]
  p_net_config    = local.state.network.infrastructure_map["core-harbor-frontend"]

  # Pure Identity SSoT from Layer 00 (Harbor MicroK8s is the 'frontend' component)
  svc_identity = local.state.metadata.global_topology_identity["harbor"]["frontend"]
  svc_fqdn     = local.state.metadata.global_pki_map["harbor-frontend"].dns_san[0]

  # Align with Postgres/Redis: Dynamic identity map for module input
  node_identities = {
    "frontend" = local.state.metadata.global_topology_identity["harbor"]["frontend"]
  }
}

# Network Context
locals {
  net_service_vip = local.p_net_config.lb_config.vip
  network_infrastructure_map = {
    default = local.p_net_config
  }
}

# Security & App Context
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_vault_ca_b64 = local.state.metadata.global_vault_pki.ca_cert

  # System Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.guest_vm.data["vm_username"]
    password             = data.vault_generic_secret.guest_vm.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.guest_vm.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.guest_vm.data["ssh_private_key_path"]
  }

  # Vault Agent Identity Prep (Harbor Frontend SANs)
  sec_vault_identity_key = "harbor-frontend"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    auth_path     = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.microk8s_agent.secret_id
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    cluster_name      = local.svc_identity.cluster_name
    storage_pool_name = local.storage_pool_name
    components        = var.service_config
  }
}

# Ansible Configuration Rendering
locals {
  ansible_template_vars = {
    ansible_user               = local.sec_system_creds.username
    microk8s_ingress_vip       = local.net_service_vip
    microk8s_allowed_subnet    = local.p_net_config.network.hostonly.cidr
    microk8s_nat_subnet_prefix = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))
  }

  ansible_extra_vars = {
    vault_ca_cert_b64     = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id   = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id = vault_approle_auth_backend_role_secret_id.microk8s_agent.secret_id
    vault_addr            = local.sys_vault_addr
    vault_role_name       = local.sec_vault_agent_identity.role_name
    service_name          = "harbor"
  }
}
