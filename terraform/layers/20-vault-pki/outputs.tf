
output "vault_ha_virtual_ip" {
  description = "The Virtual IP of the Vault Raft Cluster"
  value       = data.terraform_remote_state.vault_raft_config.outputs.vault_ha_virtual_ip
}

output "pki_configuration" {
  description = "PKI Configuration Summary"
  value = {
    path             = module.vault_pki_setup.vault_pki_path
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

output "workload_identities_dependencies" {
  description = "AppRole credentials for Dependency services"
  value = {
    for service_name, mod in module.vault_workload_identity_dependencies : service_name => {
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
