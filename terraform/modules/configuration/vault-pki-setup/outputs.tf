
# VM Services Roles (Map: Platform -> Role Name)
output "postgres_role_names" {
  description = "Map of Postgres PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-postgres"].name }
}

output "redis_role_names" {
  description = "Map of Redis PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-redis"].name }
}

output "minio_role_names" {
  description = "Map of MinIO (S3) PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-minio"].name }
}

output "dev_harbor_ingress_role_name" {
  description = "Dev Harbor Ingress PKI Role Name"
  value       = vault_pki_secret_backend_role.dev_harbor_ingress.name
}

output "harbor_ingress_role_name" {
  description = "Harbor Ingress PKI Role Name"
  value       = vault_pki_secret_backend_role.ingress["harbor"].name
}

output "gitlab_ingress_role_name" {
  description = "GitLab Ingress PKI Role Name"
  value       = vault_pki_secret_backend_role.ingress["gitlab"].name
}

# VM Services Domains (Map: Platform -> Domain List)

output "postgres_role_domains" {
  description = "Map of allowed domains for Postgres PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-postgres"].allowed_domains }
}

output "redis_role_domains" {
  description = "Map of allowed domains for Redis PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-redis"].allowed_domains }
}

output "minio_role_domains" {
  description = "Map of allowed domains for MinIO PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-minio"].allowed_domains }
}

output "dev_harbor_ingress_domains" {
  description = "List of allowed domains for Dev Harbor Ingress role"
  value       = vault_pki_secret_backend_role.dev_harbor_ingress.allowed_domains
}

output "harbor_ingress_domains" {
  description = "List of allowed domains for Harbor Ingress role"
  value       = vault_pki_secret_backend_role.ingress["harbor"].allowed_domains
}

output "gitlab_ingress_domains" {
  description = "List of allowed domains for GitLab Ingress role"
  value       = vault_pki_secret_backend_role.ingress["gitlab"].allowed_domains
}

output "vault_pki_path" {
  description = "The path of the PKI backend"
  value       = var.vault_pki_path
}

output "pki_root_ca_certificate" {
  description = "The Public Certificate of the PKI Root CA"
  value       = vault_pki_secret_backend_root_cert.prod_root_ca.certificate
}
