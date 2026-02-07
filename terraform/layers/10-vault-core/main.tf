
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  topology_config = var.vault_compute
  infra_config    = var.vault_infra

  tls_source_dir = module.vault_tls_gen.tls_source_dir
}

module "vault_tls_gen" {
  source     = "../../modules/configuration/vault-tls-gen"
  output_dir = local.layer_tls_dir

  tls_mode = var.tls_mode

  vault_cluster = {
    vault_cluster = {
      nodes = {
        for k, v in var.vault_compute.vault_cluster.nodes : k => {
          ip = v.ip
        }
      }
    }
    haproxy_config = {
      virtual_ip = var.vault_compute.haproxy_config.virtual_ip
    }
  }
}

module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"

  depends_on = [module.vault_cluster]

  providers = {
    vault = vault.target_cluster
  }
  vault_addr          = "https://${var.vault_compute.haproxy_config.virtual_ip}:443"
  root_domain         = local.root_domain
  root_ca_common_name = var.vault_pki_engine_config.root_ca_common_name

  auth_backends     = var.vault_auth_backends
  pki_engine_config = var.vault_pki_engine_config

  component_roles  = local.component_roles
  dependency_roles = local.dependency_roles
}

module "vault_workload_identity_components" {
  source = "../../modules/configuration/vault-workload-identity"

  for_each           = local.component_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]

  providers = {
    vault = vault.target_cluster
  }
}

module "vault_workload_identity_dependencies" {
  source = "../../modules/configuration/vault-workload-identity"

  for_each           = local.dependency_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]

  providers = {
    vault = vault.target_cluster
  }
}
