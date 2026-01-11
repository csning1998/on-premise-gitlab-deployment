
# For Vault Agent to apply for certs
# Role: Postgres
resource "vault_pki_secret_backend_role" "postgres" {

  for_each = local.platforms
  backend  = vault_mount.pki_prod.path
  name     = "${each.key}-postgres-role"

  allowed_domains = [
    "pg.${each.key}.${local.root_domain}",
    "${each.key}.${local.root_domain}"
  ]

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]

  server_flag = true
  client_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Role: Redis
resource "vault_pki_secret_backend_role" "redis" {

  for_each = local.platforms
  backend  = vault_mount.pki_prod.path
  name     = "${each.key}-redis-role"

  allowed_domains = [
    "redis.${each.key}.${local.root_domain}",
    "${each.key}.${local.root_domain}"
  ]

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage   = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]
  client_flag = true
  server_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours
}

# Role: MinIO
resource "vault_pki_secret_backend_role" "minio" {

  for_each = local.platforms
  backend  = vault_mount.pki_prod.path
  name     = "${each.key}-minio-role"

  allowed_domains = [
    "s3.${each.key}.${local.root_domain}",
    "console.${each.key}.${local.root_domain}",
    "${each.key}.${local.root_domain}"
  ]

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage   = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]
  client_flag = true
  server_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours
}

