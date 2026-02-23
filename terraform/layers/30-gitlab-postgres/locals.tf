
# Data Ingestion (Layer 05 Yellow Pages)
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  central_lb_outputs  = data.terraform_remote_state.central_lb.outputs
  vault_pki_state     = data.terraform_remote_state.vault_pki.outputs
  service_meta        = local.global_topology.service_structure[var.service_catalog_name]
  service_fqdn        = local.global_topology.domain_suffix
  cluster_name        = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  security_pki_bundle = try(local.global_topology.gitlab_postgres_pki, null)
  vault_prod_addr     = "https://${data.terraform_remote_state.vault_raft_config.outputs.service_vip}:443"
}

locals {
  postgres_dep_meta     = local.service_meta.dependencies["postgres"]
  postgres_service_fqdn = try(local.postgres_dep_meta.role.dns_san[0], "")
  postgres_topology     = local.central_lb_outputs.network_service_topology[local.postgres_topology_key]
  postgres_topology_key = "${var.service_catalog_name}-postgres"
  etcd_topology         = local.central_lb_outputs.network_service_topology[local.etcd_topology_key]
  etcd_topology_key     = "${var.service_catalog_name}-etcd"
}

# Network Map Construction (Multi-Tier Support)
locals {
  service_vip = local.postgres_topology.lb_config.vip

  network_bindings = {
    "postgres" = {
      nat_net_name         = local.postgres_topology.network.nat.name
      nat_bridge_name      = local.postgres_topology.network.nat.bridge_name
      hostonly_net_name    = local.postgres_topology.network.hostonly.name
      hostonly_bridge_name = local.postgres_topology.network.hostonly.bridge_name
    }
    "etcd" = {
      nat_net_name         = local.etcd_topology.network.nat.name
      nat_bridge_name      = local.etcd_topology.network.nat.bridge_name
      hostonly_net_name    = local.etcd_topology.network.hostonly.name
      hostonly_bridge_name = local.etcd_topology.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "postgres" = {
      network = {
        nat = {
          gateway = local.postgres_topology.network.nat.gateway
          cidrv4  = local.postgres_topology.network.nat.cidr
          dhcp    = local.postgres_topology.network.nat.dhcp
        }
        hostonly = {
          gateway = local.postgres_topology.network.hostonly.gateway
          cidrv4  = local.postgres_topology.network.hostonly.cidr
        }
      }
      network_access_scope = local.postgres_topology.network.hostonly.cidr
    }
    "etcd" = {
      network = {
        nat = {
          gateway = local.etcd_topology.network.nat.gateway
          cidrv4  = local.etcd_topology.network.nat.cidr
          dhcp    = local.etcd_topology.network.nat.dhcp
        }
        hostonly = {
          gateway = local.etcd_topology.network.hostonly.gateway
          cidrv4  = local.etcd_topology.network.hostonly.cidr
        }
      }
      network_access_scope = local.etcd_topology.network.hostonly.cidr
    }
  }
}

# Topology Component Construction
locals {
  storage_pool_name = "iac-${local.cluster_name}-postgres"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_postgres_config
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

  # Database Credentials (Patroni/Replication)
  credentials_postgres = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  # Key: "${service}-${dependency}-dep" -> "gitlab-postgres-dep"
  vault_identity_key = "${var.service_catalog_name}-postgres-dep"

  vault_agent_identity = {
    vault_address = local.vault_prod_addr
    role_id       = try(local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].role_id, "")
    role_name     = try(local.vault_pki_state.pki_configuration.dependency_roles[local.vault_identity_key].name, "")
    ca_cert_b64   = local.global_topology.vault_pki.ca_cert
    common_name   = local.postgres_service_fqdn
  }
}

# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "patroni_agent" {
  # Path: local.vault_pki_state -> workload_identities_dependencies -> gitlab-postgres-dep
  backend   = local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].auth_path
  role_name = local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-postgres"
    "timestamp" = timestamp()
  })
}
