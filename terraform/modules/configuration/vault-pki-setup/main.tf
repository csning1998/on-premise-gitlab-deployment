
resource "vault_auth_backend" "this" {
  for_each = var.auth_backends

  type = each.value.type
  path = each.value.path
}

# PKI Engine
resource "vault_mount" "pki_prod" {
  path        = var.pki_engine_config.path
  type        = "pki"
  description = "Production PKI Engine for internal services"

  default_lease_ttl_seconds = var.pki_engine_config.default_lease_ttl_seconds
  max_lease_ttl_seconds     = var.pki_engine_config.max_lease_ttl_seconds
}

# Root CA
resource "vault_pki_secret_backend_root_cert" "prod_root_ca" {
  backend = vault_mount.pki_prod.path

  type                 = "internal"
  common_name          = var.root_ca_common_name
  ttl                  = 60 * 60 * 24 * 365 # 1 Year
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
