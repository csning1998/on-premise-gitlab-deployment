
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

  require_cn        = false
  allow_any_name    = false
  enforce_hostnames = true
}

/**
 * `require_cn = false`
 * 
 * Reference: https://www.rfc-editor.org/rfc/rfc2818.html
 * 
 * 3.1.  Server Identity
 * 
 * If a subjectAltName extension of type dNSName is present, that MUST
 * be used as the identity. Otherwise, the (most specific) Common Name
 * field in the Subject field of the certificate MUST be used. Although
 * the use of the Common Name is existing practice, it is deprecated and
 * Certification Authorities are encouraged to use the dNSName instead.
*/
