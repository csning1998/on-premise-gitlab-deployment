
# PKI Engine
resource "vault_mount" "pki_prod" {
  path        = var.vault_pki_path
  type        = "pki"
  description = "Production PKI Engine for internal services"

  default_lease_ttl_seconds = 60 * 60 * 24       # 1 Day
  max_lease_ttl_seconds     = 60 * 60 * 24 * 365 # 1 Year
}

# Root CA
resource "vault_pki_secret_backend_root_cert" "prod_root_ca" {
  backend = vault_mount.pki_prod.path

  type                 = "internal"
  common_name          = "on-premise-gitlab-deployment-root-ca"
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

# Enable Global AppRole Auth Method
resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

# Kubernetes Auth Method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}
