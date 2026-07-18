
# 1. PKI Secrets Engine
resource "vault_mount" "pki_prod" {
  provider    = vault.production
  path        = var.pki_engine_config.path
  type        = "pki"
  description = "Production PKI Engine for internal services"

  default_lease_ttl_seconds = var.pki_engine_config.default_lease_ttl_seconds
  max_lease_ttl_seconds     = var.pki_engine_config.max_lease_ttl_seconds
}

# Hierarchical PKI configuration utilizing a Root to Intermediate certification path.
# The Root CA resides in the Bootstrap Vault; this engine stores only the signed Intermediate CA.

# 2a. Generate Intermediate CA CSR from the Production PKI engine.
resource "vault_pki_secret_backend_intermediate_cert_request" "prod_int_csr" {
  provider = vault.production
  backend  = vault_mount.pki_prod.path

  type        = "internal"
  common_name = var.pki_settings.intermediate_ca_common_name
  key_type    = "rsa"
  key_bits    = 4096
}

# 2b. Sign the Intermediate CA CSR using the Bootstrap Vault's Bootstrap Issuing Intermediate CA.
resource "vault_pki_secret_backend_root_sign_intermediate" "signed_int" {
  provider = vault.bootstrap
  backend  = var.bootstrap_pki_mount_path

  csr                  = vault_pki_secret_backend_intermediate_cert_request.prod_int_csr.csr
  common_name          = var.pki_settings.intermediate_ca_common_name
  format               = "pem"
  ttl                  = 60 * 60 * 24 * 365 # 1 Year
  exclude_cn_from_sans = true
}

# 2c. Import the complete certificate chain (Production Vault intermediate, Bootstrap Vault intermediate,
# and Bootstrap Vault root). The signed bundle contains only the intermediate certificates; the root
# certificate is appended manually.
resource "vault_pki_secret_backend_intermediate_set_signed" "prod_int_signed" {
  provider = vault.production
  backend  = vault_mount.pki_prod.path
  certificate = join("\n", [
    chomp(vault_pki_secret_backend_root_sign_intermediate.signed_int.certificate_bundle),
    chomp(var.bootstrap_root_ca_certificate_pem),
  ])
}

# Importing multiple certificates registers multiple issuers, only one of which possesses the private key.
# The key-holding issuer is dynamically resolved via `key_info`, avoiding reliance on array ordering.
data "vault_pki_secret_backend_issuers" "prod_issuers" {
  provider   = vault.production
  backend    = vault_mount.pki_prod.path
  depends_on = [vault_pki_secret_backend_intermediate_set_signed.prod_int_signed]
}

locals {
  prod_key_bearing_issuer_ids = [
    for issuer_id, key_id in data.vault_pki_secret_backend_issuers.prod_issuers.key_info :
    issuer_id if key_id != ""
  ]
}

resource "vault_pki_secret_backend_config_issuers" "prod_default" {
  provider                      = vault.production
  backend                       = vault_mount.pki_prod.path
  default                       = local.prod_key_bearing_issuer_ids[0]
  default_follows_latest_issuer = true

  lifecycle {
    precondition {
      condition     = length(local.prod_key_bearing_issuer_ids) > 0
      error_message = "The pki_prod mount does not contain any key-bearing issuers. The set-signed import operation may fail, or all certificates may be imported as keyless issuers."
    }
  }
}

# CRL and OCSP configuration URLs
resource "vault_pki_secret_backend_config_urls" "config_urls" {
  provider = vault.production
  backend  = vault_mount.pki_prod.path

  issuing_certificates    = ["${var.vault_endpoint}/v1/${vault_mount.pki_prod.path}/ca"]
  crl_distribution_points = ["${var.vault_endpoint}/v1/${vault_mount.pki_prod.path}/crl"]
}

# Unified PKI role definitions
resource "vault_pki_secret_backend_role" "pki_roles" {
  provider = vault.production
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

# 1. Shared AppRole authentication backend for workload identity
resource "vault_auth_backend" "approle" {
  provider = vault.production
  path     = "workload-approle"
  type     = "approle"
}

# 2. Isolated Kubernetes authentication backends for cluster identity isolation
resource "vault_auth_backend" "kubernetes" {
  provider = vault.production
  for_each = toset(distinct([for k, v in var.pki_roles : v.auth_path if v.auth_method == "kubernetes"]))

  path = each.value
  type = "kubernetes"
}

# Unified PKI policies for certificate signing and issuance
resource "vault_policy" "pki_policies" {
  provider = vault.production
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
