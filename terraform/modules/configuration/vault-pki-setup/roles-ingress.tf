
# Role: Generic Ingress Role
resource "vault_pki_secret_backend_role" "ingress" {
  for_each = local.ingress_services

  backend = vault_mount.pki_prod.path
  name    = "${each.key}-ingress-role"

  allowed_domains = each.value.domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true

  key_usage = [
    "DigitalSignature",
    "KeyEncipherment",
    "KeyAgreement"
  ]

  server_flag = true # Server Flag for Ingress HTTPS
  client_flag = true # Client Flag (e.g. for GitLab Rails to connect Postgres/Redis mTLS)

  max_ttl = 60 * 60 * 24 * 30 # 30 Days
  ttl     = 60 * 60 * 24      # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Policy: Generic PKI Policy. This will be bind to Cert-Manager in ServiceAccount
resource "vault_policy" "ingress_pki" {
  for_each = local.ingress_services

  name = "${each.key}-pki-policy"

  # 1. Allow the path pki/prod/sign/<service>-ingress-role to sign certificate
  # 2. Allow to sign and issue certificate for Ingress
  # 3. Allow to read CRL

  policy = <<EOT
path "${vault_mount.pki_prod.path}/sign/${each.key}-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/issue/${each.key}-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/crl" {
  capabilities = ["read"]
}
EOT
}
