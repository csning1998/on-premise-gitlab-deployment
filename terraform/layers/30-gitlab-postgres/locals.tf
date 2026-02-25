
# State Object
locals {
  state = {
    network   = data.terraform_remote_state.network.outputs
    topology  = data.terraform_remote_state.topology.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
  }
}

# Service Context
locals {
  # Using the standardized keys logic from Layer 00 defining structure
  svc_etcd_dep          = local.state.topology.service_structure[local.svc_name].dependencies["etcd"]
  svc_etcd_identity     = local.svc_etcd_dep.identity
  svc_name              = var.service_catalog_name
  svc_postgres_dep      = local.state.topology.service_structure[local.svc_name].dependencies["postgres"]
  svc_postgres_fqdn     = local.svc_postgres_dep.role.dns_san[0]
  svc_postgres_identity = local.svc_postgres_dep.identity
}

# Network Context
locals {
  # Lookups directly into Infrastructure Map from Layer 05
  net_etcd        = local.state.network.infrastructure_map[local.svc_etcd_dep.segment_key]
  net_postgres    = local.state.network.infrastructure_map[local.svc_postgres_dep.segment_key]
  net_service_vip = local.net_postgres.lb_config.vip

  # Single map of raw infrastructures for KVM
  network_infrastructure_map = {
    etcd     = local.net_etcd
    postgres = local.net_postgres
  }
}

# Security & App Context
locals {
  # Database Credentials (Patroni/Replication)
  sec_postgres_creds = {
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # System Credentials (OS/SSH)
  sec_system_creds = {
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
  }

  # Vault Agent Identity Prep
  sec_vault_agent_identity = {
    ca_cert_b64   = local.sys_vault_ca_b64
    vault_address = local.sys_vault_addr
    common_name   = local.svc_postgres_fqdn
    role_id       = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.dependency_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.postgres_agent.secret_id
  }

  sec_vault_identity_key = local.svc_postgres_dep.role.key
  sys_vault_addr         = "https://${local.state.vault_sys.service_vip}:443"
  sys_vault_ca_b64       = local.state.vault_sys.security_pki_bundle.ca_cert
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_postgres_identity.storage_pool_name
  topology_cluster = {
    components        = var.gitlab_postgres_config
    storage_pool_name = local.storage_pool_name
  }
}

# Ansible Configuration Integration
locals {
  ansible_extra_vars = {
    pg_replication_password = local.sec_postgres_creds.replication_password
    pg_superuser_password   = local.sec_postgres_creds.superuser_password
    pg_vrrp_secret          = local.sec_postgres_creds.vrrp_secret
    vault_agent_common_name = local.sec_vault_agent_identity.common_name
  }

  ansible_template_vars = {
    nat_prefix   = join(".", slice(split(".", local.net_postgres.network.nat.gateway), 0, 3))
    access_scope = local.net_postgres.network.hostonly.cidr
    postgres_vip = local.net_service_vip
    vault_vip    = local.state.vault_sys.service_vip
  }
}
