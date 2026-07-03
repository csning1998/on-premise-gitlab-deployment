
output "vault_service_vip" {
  description = "The Virtual IP of the Vault Raft Cluster"
  value       = local.state.vault_sys.service_vip
}

output "pki_configuration" {
  description = "PKI Configuration Summary"
  value = {
    path                            = module.vault_pki_setup.vault_pki_path
    pki_roles                       = module.vault_pki_setup.pki_roles
    root_ca_certificate_b64         = module.vault_pki_setup.pki_root_ca_certificate_b64
    intermediate_ca_certificate_b64 = module.vault_pki_setup.pki_intermediate_ca_certificate_b64
    lease_durations = {
      default = format("%dh", var.vault_pki_engine_config.default_lease_ttl_seconds / 3600)
      max     = format("%dh", var.vault_pki_engine_config.max_lease_ttl_seconds / 3600)
      agent   = var.environment == "production" ? "24h" : "12h"
    }
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

output "bootstrap_ca_b64" {
  description = "Aggregated Trust Bundle (Bootstrap CA + PKI CA)"
  value = {
    path        = local_file.trust_bundle.filename
    content_b64 = base64encode(local_file.trust_bundle.content)
  }
}

output "management_policies" {
  description = "Map of management policy names"
  value       = { for k in local.management_identities : k => module.vault_workload_identity_approle[k].policy_name }
}

output "vault_kv_namespace" {
  description = "Pass-through of L00 Vault KV namespace prefix; consumed by L30+ for credential path construction without reading L00 directly."
  value       = local.state.metadata.vault_kv_namespace
}

output "global_pki_map" {
  description = "Pass-through of L00 PKI role map (DNS SANs, role names, auth config); consumed by L30+ for TLS certificate configuration."
  value       = local.state.metadata.global_pki_map
}

output "global_credential_paths" {
  description = "Pass-through of L00 credential path map; consumed by L30+ for Vault KV path construction."
  value       = local.state.metadata.global_credential_paths
}

output "ca_cert_path" {
  description = "Pass-through of L15 Bootstrap CA certificate file path; consumed by L30+ for Vault provider TLS verification."
  value       = local.state.vault_sys.ca_cert_path
}

output "global_vault_pki_b64" {
  description = "Pass-through of L00 Bootstrap Vault TLS artifacts (CA cert, server cert/key, HAProxy bundle); consumed by L30+ as the trust chain root."
  value       = local.state.metadata.global_vault_pki_b64
  sensitive   = true
}
