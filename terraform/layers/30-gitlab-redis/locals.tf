
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
  svc_name           = var.service_catalog_name
  svc_redis_dep      = local.state.topology.service_structure[local.svc_name].dependencies["redis"]
  svc_redis_identity = local.svc_redis_dep.identity
  svc_cluster_name   = local.svc_redis_identity.cluster_name
  svc_redis_fqdn     = local.svc_redis_dep.role.dns_san[0]
}

# Network Context
locals {
  # Lookups directly into Infrastructure Map from Layer 05
  net_redis       = local.state.network.infrastructure_map[local.svc_redis_dep.segment_key]
  net_service_vip = local.net_redis.lb_config.vip

  # Single map of raw infrastructures for KVM
  network_infrastructure_map = {
    redis = local.net_redis
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
  sec_redis_creds = {
    masterauth  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
    requirepass = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    vrrp_secret = data.vault_generic_secret.db_vars.data["redis_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  sec_vault_identity_key = local.svc_redis_dep.role.key

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.dependency_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_redis_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_redis_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_redis_config
  }
}

# Ansible Configuration Rendering
locals {
  ansible_template_vars = {
    redis_vip            = local.net_service_vip
    vault_vip            = regex("://([^:]+)", local.sys_vault_addr)[0]
    access_scope         = local.net_redis.network.hostonly.cidr
    redis_tls_port       = local.net_redis.lb_config.ports["main"].frontend_port
    redis_service_domain = local.sec_vault_agent_identity.common_name
  }

  ansible_extra_vars = {
    vault_ca_cert_b64       = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id     = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id   = vault_approle_auth_backend_role_secret_id.redis_agent.secret_id
    vault_addr              = local.sys_vault_addr
    vault_role_name         = local.sec_vault_agent_identity.role_name
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
    redis_masterauth        = local.sec_redis_creds.masterauth
    redis_requirepass       = local.sec_redis_creds.requirepass
    redis_vrrp_secret       = local.sec_redis_creds.vrrp_secret
  }
}
