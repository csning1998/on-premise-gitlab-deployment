
# Role: Internal Database Services (Postgres, Redis, MinIO)
resource "vault_pki_secret_backend_role" "dependency_roles" {
  for_each = var.dependency_roles

  backend         = vault_mount.pki_prod.path
  name            = each.value.name
  allowed_domains = each.value.allowed_domains

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]

  server_flag = true
  client_flag = true

  # Metadata Injection same as in dependency roles
  ou = each.value.ou

  max_ttl = each.value.max_ttl
  ttl     = each.value.ttl

  allow_any_name    = false
  enforce_hostnames = true
}
