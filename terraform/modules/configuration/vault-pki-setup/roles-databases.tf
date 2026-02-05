
# Role: Internal Database Services (Postgres, Redis, MinIO)
resource "vault_pki_secret_backend_role" "db_services" {
  for_each = local.db_roles_flat

  backend = vault_mount.pki_prod.path
  name    = "${each.value.platform}-${each.value.service}-role"

  # Iterate through prefixes plus platform domain, finally add a bare domain item
  allowed_domains = concat(
    [for p in each.value.prefixes : "${p}.${each.value.platform}.${local.root_domain}"],
    ["${each.value.platform}.${local.root_domain}"]
  )

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]

  server_flag = true
  client_flag = true

  max_ttl = 60 * 60 * 24 * 30 # 30 Days
  ttl     = 60 * 60 * 24      # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}
