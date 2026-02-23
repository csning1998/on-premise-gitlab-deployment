
# Data Ingestion (Layer 05 Yellow Pages)
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  central_lb_outputs  = data.terraform_remote_state.central_lb.outputs
  vault_pki_state     = data.terraform_remote_state.vault_pki.outputs
  service_meta        = local.global_topology.service_structure[var.service_catalog_name]
  service_fqdn        = local.global_topology.domain_suffix
  cluster_name        = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  security_pki_bundle = try(local.global_topology.gitlab_kubeadm_pki, null)
  vault_prod_addr     = "https://${data.terraform_remote_state.vault_raft_config.outputs.service_vip}:443"
}

locals {
  kubeadm_comp_meta    = local.service_meta.components["frontend"]
  kubeadm_service_fqdn = try(local.kubeadm_comp_meta.dns_san[0], local.service_fqdn)
  kubeadm_topology_key = var.service_catalog_name
  kubeadm_topology     = local.central_lb_outputs.network_service_topology[local.kubeadm_topology_key]
}

# Network Map Construction (Multi-Tier Support)
locals {
  service_vip = local.kubeadm_topology.lb_config.vip

  network_bindings = {
    "default" = {
      nat_net_name         = local.kubeadm_topology.network.nat.name
      nat_bridge_name      = local.kubeadm_topology.network.nat.bridge_name
      hostonly_net_name    = local.kubeadm_topology.network.hostonly.name
      hostonly_bridge_name = local.kubeadm_topology.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "default" = {
      network = {
        nat = {
          gateway = local.kubeadm_topology.network.nat.gateway
          cidrv4  = local.kubeadm_topology.network.nat.cidr
          dhcp    = local.kubeadm_topology.network.nat.dhcp
        }
        hostonly = {
          gateway = local.kubeadm_topology.network.hostonly.gateway
          cidrv4  = local.kubeadm_topology.network.hostonly.cidr
        }
      }
      network_access_scope = local.kubeadm_topology.network.hostonly.cidr
    }
  }
}

# Topology Component Construction
locals {
  storage_pool_name = "iac-${local.cluster_name}-gitlab-kubeadm"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_kubeadm_config
  }
}

# Credentials
locals {
  # System Credentials (OS/SSH)
  credentials_system = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Vault Agent Identity Prep
  # Key: "${service}-${dependency}-dep" -> "gitlab-kubeadm-dep"
  vault_identity_key = "${var.service_catalog_name}-frontend"
  vault_agent_identity = {
    vault_address = local.vault_prod_addr
    role_id       = try(local.vault_pki_state.workload_identities_components[local.vault_identity_key].role_id, "")
    role_name     = try(local.vault_pki_state.pki_configuration.component_roles[local.vault_identity_key].name, "")
    ca_cert_b64   = local.global_topology.vault_pki.ca_cert
    common_name   = local.kubeadm_service_fqdn
  }
}

# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "kubeadm_agent" {
  # Path: local.vault_pki_state -> workload_identities_dependencies -> gitlab-kubeadm-dep
  backend   = local.vault_pki_state.workload_identities_components[local.vault_identity_key].auth_path
  role_name = local.vault_pki_state.workload_identities_components[local.vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-40-gitlab-kubeadm"
    "timestamp" = timestamp()
  })
}
