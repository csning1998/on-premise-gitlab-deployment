
# Role: Generic Ingress Role
resource "vault_pki_secret_backend_role" "component_roles" {
  for_each = var.component_roles

  backend         = vault_mount.pki_prod.path
  name            = each.value.name
  allowed_domains = each.value.allowed_domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true

  key_usage = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]

  server_flag = true # Server Flag for Ingress HTTPS
  client_flag = true # Client Flag (e.g. for GitLab Rails to connect Postgres/Redis mTLS)

  max_ttl = each.value.max_ttl
  ttl     = each.value.ttl

  # Metadata Injection same as in dependency roles
  ou = each.value.ou

  allow_any_name    = false
  enforce_hostnames = true
}

# Policy: Generic PKI Policy. This will be bind to Cert-Manager in ServiceAccount
resource "vault_policy" "component_roles_pki" {
  for_each = var.component_roles

  name = "${each.value.name}-pki-policy"

  # 1. Allow the path pki/prod/sign/<service>-ingress-role to sign certificate
  # 2. Allow to sign and issue certificate for Ingress
  # 3. Allow to read CRL

  policy = <<EOT
path "${vault_mount.pki_prod.path}/sign/${each.value.name}" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/issue/${each.value.name}" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/crl" {
  capabilities = ["read"]
}
EOT
}
