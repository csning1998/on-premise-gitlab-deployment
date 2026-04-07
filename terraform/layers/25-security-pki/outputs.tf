
output "vault_service_vip" {
  description = "The Virtual IP of the Vault Raft Cluster"
  value       = local.state.vault_sys.service_vip
}

output "pki_configuration" {
  description = "PKI Configuration Summary"
  value = {
    path             = module.vault_pki_setup.vault_pki_path
    ca_cert          = base64encode(module.vault_pki_setup.pki_root_ca_certificate)
    dependency_roles = module.vault_pki_setup.dependency_roles
    component_roles  = module.vault_pki_setup.component_roles
  }
}

output "workload_identities_components" {
  description = "AppRole credentials for Component services"
  value = {
    for service_name, mod in module.vault_workload_identity_components : service_name => {
      role_id   = mod.approle_role_id
      role_name = mod.approle_name
      auth_path = mod.approle_path
    }
  }
}

output "auth_backend_paths" {
  description = "Map of enabled Auth Backend paths"
  value       = module.vault_pki_setup.auth_backend_paths
}

output "bootstrap_ca" {
  description = "Bootstrap CA certificate details"
  value = {
    path    = local.bootstrap_ca_path
    content = base64encode(file(local.bootstrap_ca_path))
  }
}
