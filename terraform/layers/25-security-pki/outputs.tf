
output "vault_service_vip" {
  description = "The Virtual IP of the Vault Raft Cluster"
  value       = local.state.vault_sys.service_vip
}

output "pki_configuration" {
  description = "PKI Configuration Summary"
  value = {
    path                 = module.vault_pki_setup.vault_pki_path
    pki_roles            = module.vault_pki_setup.pki_roles
    ca_cert              = base64encode(module.vault_pki_setup.pki_root_ca_certificate)
    vault_agent_cert_ttl = var.environment == "production" ? "12h" : "5m"
  }
}

output "workload_identities_approle" {
  description = "AppRole credentials for Dependency/AppRole services"
  value = {
    for service_name, mod in module.vault_workload_identity_approle : service_name => {
      role_id   = mod.approle_role_id
      role_name = mod.approle_name
      auth_path = module.vault_pki_setup.auth_backend_paths["approle"]
    }
  }
}

output "workload_identities_kubernetes" {
  description = "Kubernetes Auth Roles for Component services"
  value = {
    for service_name, role in vault_kubernetes_auth_backend_role.kubernetes_role : service_name => {
      role_id   = role.id
      role_name = role.role_name
      auth_path = role.backend
    }
  }
}

output "auth_backend_paths" {
  description = "Map of enabled Auth Backend paths"
  value       = module.vault_pki_setup.auth_backend_paths
}

output "bootstrap_ca" {
  description = "Aggregated Trust Bundle (Bootstrap CA + PKI CA)"
  value = {
    path    = local_file.trust_bundle.filename
    content = base64encode(local_file.trust_bundle.content)
  }
}
