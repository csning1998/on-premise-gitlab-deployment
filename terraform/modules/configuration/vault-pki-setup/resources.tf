
# 1. PKI Engine
resource "vault_mount" "pki_prod" {
  path        = var.pki_engine_config.path
  type        = "pki"
  description = "Production PKI Engine for internal services"

  default_lease_ttl_seconds = var.pki_engine_config.default_lease_ttl_seconds
  max_lease_ttl_seconds     = var.pki_engine_config.max_lease_ttl_seconds
}

# --- Hierarchical PKI Refactoring (Root -> Intermediate) ---

# 2a. Bootstrap Root Engine (Internal use only for signing the intermediate)
resource "vault_mount" "pki_root_bootstrap" {
  path        = "pki-infrastructure-root-bootstrap"
  type        = "pki"
  description = "Internal bootstrap engine to host the Infrastructure Root CA for signing"

  default_lease_ttl_seconds = var.pki_engine_config.default_lease_ttl_seconds
  max_lease_ttl_seconds     = var.pki_engine_config.max_lease_ttl_seconds
}

# 2b. Import the Infrastructure Root CA (from L00) into the bootstrap engine
resource "vault_pki_secret_backend_config_ca" "root_ca_config" {
  backend    = vault_mount.pki_root_bootstrap.path
  pem_bundle = "${var.root_ca_cert}\n${var.root_ca_key}"
}

# 2c. Generate Intermediate CSR from the Production Engine
resource "vault_pki_secret_backend_intermediate_cert_request" "prod_int_csr" {
  backend = vault_mount.pki_prod.path

  type        = "internal"
  common_name = var.pki_settings.intermediate_ca_common_name
  key_type    = "rsa"
  key_bits    = 4096
}

# 2d. Sign the Intermediate CSR using the Bootstrap Root (Referencing Vault Docs)
resource "vault_pki_secret_backend_root_sign_intermediate" "signed_int" {
  depends_on = [vault_pki_secret_backend_config_ca.root_ca_config]
  backend    = vault_mount.pki_root_bootstrap.path

  csr                  = vault_pki_secret_backend_intermediate_cert_request.prod_int_csr.csr
  common_name          = var.pki_settings.intermediate_ca_common_name
  format               = "pem"
  ttl                  = 60 * 60 * 24 * 365 # 1 Year (Match original Root TTL)
  exclude_cn_from_sans = true
}

# 2e. Set the signed Intermediate certificate back to the Production Engine
resource "vault_pki_secret_backend_intermediate_set_signed" "prod_int_signed" {
  backend     = vault_mount.pki_prod.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.signed_int.certificate
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

# 1. Shared AppRole Backend (Standard approach for workload identity)
resource "vault_auth_backend" "approle" {
  path = "workload-approle"
  type = "approle"
}

# 2. Kubernetes Auth Backends (One per cluster for identity isolation)
resource "vault_auth_backend" "kubernetes" {
  for_each = toset(distinct([for k, v in var.pki_roles : v.auth_path if v.auth_method == "kubernetes"]))

  path = each.value
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
