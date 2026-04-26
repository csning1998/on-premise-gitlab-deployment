
# State Object
locals {
  state = {
    metadata        = data.terraform_remote_state.metadata.outputs
    volume          = data.terraform_remote_state.volume.outputs
    network         = data.terraform_remote_state.load_balancer.outputs
    vault_sys       = data.terraform_remote_state.vault_sys.outputs
    vault_pki       = data.terraform_remote_state.vault_pki.outputs
    harbor_registry = data.terraform_remote_state.harbor_bootstrapper.outputs
    harbor_proxy    = data.terraform_remote_state.harbor_proxy.outputs
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
  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"

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
    auth_path     = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].auth_path
    role_id       = local.state.vault_pki.workload_identities_approle[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.pki_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.state.vault_pki.bootstrap_ca.content
    secret_id     = vault_approle_auth_backend_role_secret_id.microk8s_agent.secret_id
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

# Ansible Infrastructure Template Variables
locals {
  # Dependency discovery: Use the physical SSoT key for the Harbor registry.
  registry_pki_key = local.state.harbor_registry.pki_key

  ansible_template_vars = {
    ansible_user               = local.sec_system_creds.username
    microk8s_ingress_vip       = local.net_service_vip
    microk8s_allowed_subnet    = local.p_net_config.network.hostonly.cidr
    microk8s_nat_subnet_prefix = join(".", slice(split(".", local.p_net_config.network.nat.gateway), 0, 3))

    registry_host = local.state.metadata.global_pki_map[local.registry_pki_key].dns_san[0]
    registry_vip  = local.state.harbor_registry.service_vip

    # Injected Host Overrides
    node_extra_hosts = [
      { host = local.svc_fqdn, ip = local.net_service_vip },
      { host = local.state.metadata.global_pki_map[local.registry_pki_key].dns_san[0], ip = local.state.harbor_registry.service_vip }
    ]

    # Mirroring Paths
    harbor_docker_proxy = local.state.harbor_proxy.proxy_caches["docker_hub"].project_name
    harbor_quay_proxy   = local.state.harbor_proxy.proxy_caches["quay_io"].project_name
    harbor_k8s_proxy    = local.state.harbor_proxy.proxy_caches["k8s_io"].project_name
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
