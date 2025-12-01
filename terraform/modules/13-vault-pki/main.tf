
# PKI Engine
resource "vault_mount" "pki_prod" {
  path        = "pki/prod"
  type        = "pki"
  description = "Production PKI Engine for internal services"

  default_lease_ttl_seconds = 86400     # 1 Day
  max_lease_ttl_seconds     = 315360000 # 10 Years
}

# Root CA
resource "vault_pki_secret_backend_root_cert" "prod_root_ca" {
  backend = vault_mount.pki_prod.path

  type                 = "internal"
  common_name          = "on-premise-gitlab-deployment-root-ca"
  ttl                  = "315360000" # 10 Years
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
}

# CRL/OSCP URL
resource "vault_pki_secret_backend_config_urls" "config_urls" {
  backend = vault_mount.pki_prod.path

  issuing_certificates    = ["${var.vault_addr}/v1/${vault_mount.pki_prod.path}/ca"]
  crl_distribution_points = ["${var.vault_addr}/v1/${vault_mount.pki_prod.path}/crl"]
}

# Role: Posrges for Vault Agent to apply for certs
resource "vault_pki_secret_backend_role" "postgres" {
  backend = vault_mount.pki_prod.path
  name    = "postgres-role"

  allowed_domains = [
    "postgres.iac.local",
    "harbor-postgres",
    "iac.local",
    "local",
    "localhost"
  ]

  allow_subdomains   = true
  allow_glob_domains = true
  allow_ip_sans      = true

  key_usage = [
    "DigitalSignature",
    "KeyAgreement",
    "KeyEncipherment"
  ]

  server_flag = true
  client_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}
