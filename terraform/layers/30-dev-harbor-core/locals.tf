
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
  svc_name            = var.service_catalog_name
  svc_comp            = local.state.topology.service_structure[local.svc_name].components["frontend"]
  svc_identity        = local.svc_comp.identity
  svc_dev_harbor_fqdn = local.svc_comp.role.dns_san[0]
}

# Network Context
locals {
  # Lookup via service-level segment_key (same pattern as microk8s)
  net_config      = local.state.network.infrastructure_map[local.state.topology.service_structure[local.svc_name].network.segment_key]
  net_service_vip = local.net_config.lb_config.vip

  # Single-tier map keyed as "default" for HA middleware compatibility
  network_infrastructure_map = {
    default = local.net_config
  }
}

# Security & App Context
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_vault_ca_b64 = local.state.topology.vault_pki.ca_cert

  sec_system_creds = {
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
  }

  sec_app_creds = {
    harbor_admin_password = data.vault_generic_secret.db_vars.data["dev_harbor_admin_password"]
    harbor_pg_db_password = data.vault_generic_secret.db_vars.data["dev_harbor_pg_db_password"]
  }

  sec_vault_identity_key = local.svc_comp.role.key

  sec_vault_agent_identity = {
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_dev_harbor_fqdn
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name
    secret_id     = vault_approle_auth_backend_role_secret_id.bootstrap_harbor_agent.secret_id
    vault_address = local.sys_vault_addr
  }
}

# Topology Component Construction (single node wrapped as HA-compatible components map)
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    storage_pool_name = local.storage_pool_name

    components = {
      (var.bootstrap_harbor_config.role) = {
        base_image_path = var.bootstrap_harbor_config.base_image_path
        role            = var.bootstrap_harbor_config.role
        network_tier    = "default"

        nodes = {
          "00" = {
            ip_suffix  = var.bootstrap_harbor_config.node.ip_suffix
            vcpu       = var.bootstrap_harbor_config.node.vcpu
            ram        = var.bootstrap_harbor_config.node.ram
            data_disks = var.bootstrap_harbor_config.node.data_disks
          }
        }
      }
    }
  }
}

# Ansible Configuration
locals {
  ansible_template_vars = {
    access_scope        = local.net_config.network.hostonly.cidr
    dev_harbor_tls_port = local.net_config.lb_config.ports["https"].frontend_port
    dev_harbor_vip      = local.net_service_vip
    nat_gateway         = local.net_config.network.nat.gateway
    service_name        = local.svc_name
    vault_vip           = local.state.vault_sys.service_vip
  }

  ansible_extra_vars = {
    dev_harbor_admin_password = local.sec_app_creds.harbor_admin_password
    dev_harbor_pg_db_password = local.sec_app_creds.harbor_pg_db_password
    terraform_runner_subnet   = local.net_config.network.hostonly.cidr
  }
}
