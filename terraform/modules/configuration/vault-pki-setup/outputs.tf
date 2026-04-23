
output "vault_pki_path" {
  description = "The path where PKI engine is mounted"
  value       = vault_mount.pki_prod.path
}

output "pki_root_ca_certificate" {
  description = "The root CA certificate of the PKI engine"
  value       = vault_pki_secret_backend_root_cert.prod_root_ca.certificate
}

output "pki_roles" {
  description = "Map of provisioned PKI Roles with encapsulated attributes"
  value = {
    for k, v in vault_pki_secret_backend_role.pki_roles : k => {
      id              = v.id
      name            = v.name
      allowed_domains = v.allowed_domains
    }
  }
}

output "auth_backend_paths" {
  description = "Map of enabled Auth Backend paths"
  value = merge(
    { for k, v in vault_auth_backend.approle : v.path => v.path },
    { for k, v in vault_auth_backend.kubernetes : v.path => v.path }
  )
}
