
# This layer is the first component to connect to the Dev Vault.
# 1. Root CA (for internal use only) that signs the Bootstrap Issuing Intermediate.
resource "vault_mount" "pki_root" {
  path        = "pki"
  type        = "pki"
  description = "Infrastructure Root CA. Signs only the Bootstrap Issuing Intermediate."

  default_lease_ttl_seconds = 60 * 60 * 24 * 365 * 10 # 10 Years
  max_lease_ttl_seconds     = 60 * 60 * 24 * 365 * 10
}

resource "vault_pki_secret_backend_root_cert" "root" {
  backend     = vault_mount.pki_root.path
  type        = "internal"
  common_name = local.state.metadata.global_pki_config.root_ca_common_name
  ttl         = "87600h" # 10 Years
}

# The TLS CA certificate for the Dev Vault listener is unavailable in remote state.
data "local_file" "vault_dev_ca" {
  filename = abspath("${path.root}/../../../vault/tls/ca.pem")
}

# The certificate is copied to the local directory of this layer to allow downstream layers
# to read it via remote state outputs, avoiding duplicate hardcoded relative paths.
resource "local_file" "vault_dev_ca_copy" {
  content  = data.local_file.vault_dev_ca.content
  filename = "${path.root}/tls/vault-dev-ca.crt"
}

# 2. Bootstrap Issuing Intermediate.
resource "vault_mount" "pki_bootstrap_int" {
  path        = "pki_int"
  type        = "pki"
  description = "Bootstrap Issuing Intermediate. Issues pre-Production-Vault leaf certificates and signs the Production Vault intermediate."

  default_lease_ttl_seconds = 60 * 60 * 24 * 365 # 1 Year
  max_lease_ttl_seconds     = 60 * 60 * 24 * 365
}

resource "vault_pki_secret_backend_intermediate_cert_request" "bootstrap_int_csr" {
  backend = vault_mount.pki_bootstrap_int.path

  type        = "internal"
  common_name = local.state.metadata.global_pki_config.intermediate_ca_common_name
  key_type    = "rsa"
  key_bits    = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "bootstrap_int_signed" {
  depends_on = [vault_pki_secret_backend_root_cert.root]
  backend    = vault_mount.pki_root.path

  csr                  = vault_pki_secret_backend_intermediate_cert_request.bootstrap_int_csr.csr
  common_name          = local.state.metadata.global_pki_config.intermediate_ca_common_name
  format               = "pem"
  ttl                  = 60 * 60 * 24 * 365 # 1 Year
  exclude_cn_from_sans = true
}

# Importing only the intermediate certificate avoids registering a keyless root issuer and causing
# default issuer ambiguity. The root is distributed separately.
resource "vault_pki_secret_backend_intermediate_set_signed" "bootstrap_int_set" {
  backend     = vault_mount.pki_bootstrap_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.bootstrap_int_signed.certificate
}

resource "vault_pki_secret_backend_config_urls" "bootstrap_int_urls" {
  backend = vault_mount.pki_bootstrap_int.path

  issuing_certificates    = ["${var.vault_dev_endpoint}/v1/${vault_mount.pki_bootstrap_int.path}/ca"]
  crl_distribution_points = ["${var.vault_dev_endpoint}/v1/${vault_mount.pki_bootstrap_int.path}/crl"]
}

# Explicitly defines the default issuer (index 0) because Vault does not automatically select one.
resource "vault_pki_secret_backend_config_issuers" "bootstrap_int_default" {
  backend                       = vault_mount.pki_bootstrap_int.path
  default                       = vault_pki_secret_backend_intermediate_set_signed.bootstrap_int_set.imported_issuers[0]
  default_follows_latest_issuer = true
}

# 3. Bootstrap Leaf Roles
#
# Each role permits certificate issuance for a single service identity, scoped to its DNS SAN.
# IP SANs are allowed but not statically defined, as real Central LB node IPs are determined
# at Layer 10 and supplied dynamically during issuance.
resource "vault_pki_secret_backend_role" "bootstrap_leaf" {
  for_each = local.bootstrap_leaf_roles

  backend = vault_mount.pki_bootstrap_int.path
  name    = each.key

  allowed_domains    = each.value.allowed_domains
  allow_subdomains   = false
  allow_glob_domains = false
  allow_bare_domains = true
  allow_ip_sans      = true
  require_cn         = true
  enforce_hostnames  = true
  allow_any_name     = false

  key_usage = ["DigitalSignature", "KeyEncipherment"]

  server_flag = true
  client_flag = true

  max_ttl = 60 * 60 * 24 * 90 # 90 Days
  ttl     = 60 * 60 * 24 * 30 # 30 Days

  ou = each.value.ou
}
