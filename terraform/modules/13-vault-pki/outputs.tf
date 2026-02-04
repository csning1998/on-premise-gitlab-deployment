
# VM Services Roles (Map: Platform -> Role Name)
output "postgres_role_names" {
  description = "Map of Postgres PKI Role Names by platform"
  value       = { for k, v in vault_pki_secret_backend_role.postgres : k => v.name }
}

output "redis_role_names" {
  description = "Map of Redis PKI Role Names by platform"
  value       = { for k, v in vault_pki_secret_backend_role.redis : k => v.name }
}

output "minio_role_names" {
  description = "Map of MinIO (S3) PKI Role Names by platform"
  value       = { for k, v in vault_pki_secret_backend_role.minio : k => v.name }
}

output "harbor_ingress_role_name" {
  description = "Harbor Ingress PKI Role Name"
  value       = vault_pki_secret_backend_role.harbor_ingress.name
}

output "gitlab_ingress_role_name" {
  description = "GitLab Ingress PKI Role Name"
  value       = vault_pki_secret_backend_role.gitlab_ingress.name
}

# VM Services Domains (Map: Platform -> Domain List)

output "postgres_role_domains" {
  description = "Map of allowed domains for Postgres PKI roles by platform"
  value       = { for k, v in vault_pki_secret_backend_role.postgres : k => v.allowed_domains }
}

output "redis_role_domains" {
  description = "Map of allowed domains for Redis PKI roles by platform"
  value       = { for k, v in vault_pki_secret_backend_role.redis : k => v.allowed_domains }
}

output "minio_role_domains" {
  description = "Map of allowed domains for MinIO PKI roles by platform"
  value       = { for k, v in vault_pki_secret_backend_role.minio : k => v.allowed_domains }
}

output "harbor_ingress_domains" {
  description = "List of allowed domains for Harbor Ingress role"
  value       = vault_pki_secret_backend_role.harbor_ingress.allowed_domains
}

output "gitlab_ingress_domains" {
  description = "List of allowed domains for GitLab Ingress role"
  value       = vault_pki_secret_backend_role.gitlab_ingress.allowed_domains
}

output "vault_pki_path" {
  description = "The path of the PKI backend"
  value       = var.vault_pki_path
}

output "pki_root_ca_certificate" {
  description = "The Public Certificate of the PKI Root CA"
  value       = vault_pki_secret_backend_root_cert.prod_root_ca.certificate
}
