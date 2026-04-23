
# 1. PKI Engine
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

# Unified PKI Role Definition
resource "vault_pki_secret_backend_role" "pki_roles" {
  for_each = var.pki_roles

  backend         = vault_mount.pki_prod.path
  name            = each.value.name
  allowed_domains = each.value.allowed_domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true
  require_cn         = true

  key_usage = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]

  server_flag = true
  client_flag = true

  max_ttl = each.value.max_ttl
  ttl     = each.value.ttl

  ou = each.value.ou

  allow_any_name    = false
  enforce_hostnames = true
}

# 1. Universal AppRole Backends (One per role for node identity)
resource "vault_auth_backend" "approle" {
  for_each = var.pki_roles

  path = each.value.approle_path
  type = "approle"
}

# 2. Kubernetes Auth Backends (Optional, for Pod identity)
resource "vault_auth_backend" "kubernetes" {
  for_each = { for k, v in var.pki_roles : k => v if v.auth_method == "kubernetes" }

  path = each.value.auth_path
  type = "kubernetes"
}

# Unified PKI Policy Definition
resource "vault_policy" "pki_policies" {
  for_each = var.pki_roles

  name = "${each.value.name}-pki-policy"

  policy = jsonencode({
    path = {
      "${vault_mount.pki_prod.path}/sign/${each.value.name}" = {
        capabilities = ["create", "update"]
      }
      "${vault_mount.pki_prod.path}/issue/${each.value.name}" = {
        capabilities = ["create", "update"]
      }
      "${vault_mount.pki_prod.path}/crl" = {
        capabilities = ["read"]
      }
    }
  })
}
