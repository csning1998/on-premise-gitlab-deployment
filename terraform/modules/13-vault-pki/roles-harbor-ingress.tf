
# Kubernetes Auth Method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Role: Harbor Ingress on Microk8s
resource "vault_pki_secret_backend_role" "harbor_ingress" {
  backend = vault_mount.pki_prod.path
  name    = "harbor-ingress-role"

  allowed_domains = local.harbor_ingress_domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true

  key_usage = [
    "DigitalSignature",
    "KeyEncipherment",
    "KeyAgreement"
  ]

  server_flag = true
  client_flag = true

  max_ttl = 60 * 60 * 24 * 30 # 30 Days
  ttl     = 60 * 60 * 24      # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Role: Dev Harbor Ingress on Docker
resource "vault_pki_secret_backend_role" "dev_harbor_ingress" {
  backend = vault_mount.pki_prod.path
  name    = "dev-harbor-ingress-role"

  allowed_domains = local.dev_harbor_ingress_domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true

  key_usage = [
    "DigitalSignature",
    "KeyEncipherment",
    "KeyAgreement"
  ]

  server_flag = true
  client_flag = true

  max_ttl = 60 * 60 * 24 * 30 # 30 Days
  ttl     = 60 * 60 * 24      # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Policy: Allow usage of the Harbor Role. This will be bind to Cert-Manager in ServiceAccount of Microk8s
resource "vault_policy" "harbor_pki" {
  name = "harbor-pki-policy"

  # 1. Allow the path pki/prod/sign/harbor-ingress-role to sign certificate
  # 2. Allow to sign and issue certificate for Harbor Ingress
  # 3. Allow to read CRL
  policy = <<EOT
path "${vault_mount.pki_prod.path}/sign/harbor-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/issue/harbor-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/crl" {
  capabilities = ["read"]
}
EOT
}
