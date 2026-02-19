
# Metadata Ingestion & Single Source of Truth
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  central_lb_outputs  = data.terraform_remote_state.central_lb.outputs
  service_meta        = local.global_topology.service_structure[var.service_catalog_name]
  service_fqdn        = local.global_topology.domain_suffix
  cluster_name        = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  security_pki_bundle = try(local.global_topology.vault_pki, null) # PKI Artifacts
  vault_topology      = local.central_lb_outputs.network_service_topology[var.service_catalog_name]
}

# Network Semantics for Infrastructure & Application
locals {
  service_vip = local.vault_topology.lb_config.vip # Application VIP

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "vault" = {
      nat_net_name         = local.vault_topology.network.nat.name
      nat_bridge_name      = local.vault_topology.network.nat.bridge_name
      hostonly_net_name    = local.vault_topology.network.hostonly.name
      hostonly_bridge_name = local.vault_topology.network.hostonly.bridge_name
    }
  }

  # Network Parameters: L3 Routing & Configuration
  network_parameters = {
    "vault" = {
      network = {
        nat = {
          gateway = local.vault_topology.network.nat.gateway
          cidrv4  = local.vault_topology.network.nat.cidr
          dhcp    = local.vault_topology.network.nat.dhcp
        }
        hostonly = {
          gateway = local.vault_topology.network.hostonly.gateway
          cidrv4  = local.vault_topology.network.hostonly.cidr
        }
      }
      network_access_scope = local.vault_topology.network.hostonly.cidr
    }
  }
}

# Security & Credentials
locals {
  # System Level Credentials (OS/SSH)
  credentials_system = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}

# Compute Topology / VM Specifications
locals {
  storage_pool_name = "iac-${local.cluster_name}"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.vault_config
  }
}
