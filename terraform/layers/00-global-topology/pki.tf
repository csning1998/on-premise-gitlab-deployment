
# Rotation Trigger if pki_force_rotate is true
resource "terraform_data" "pki_rotate" {
  input = var.pki_force_rotate ? timestamp() : "static"
}

locals {
  # 1. Locate Vault Service Definition from Catalog
  vault_svc = [for s in var.service_catalog : s if s.name == "vault"][0]

  # 2. Calculate Network Details for Vault
  vault_cidr = cidrsubnet(var.network_baseline.cidr_block, 8, local.vault_svc.cidr_index)
  vault_vip  = cidrhost(local.vault_cidr, var.network_baseline.vip_offset)

  # 3. Calculate All Potential Node IPs in the Range
  vault_node_ips = [
    for i in range(local.vault_svc.ip_range.end_ip - local.vault_svc.ip_range.start_ip + 1) :
    cidrhost(local.vault_cidr, local.vault_svc.ip_range.start_ip + i)
  ]
}

# Self-Signed Root CA
resource "tls_private_key" "root_ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "root_ca" {
  private_key_pem = tls_private_key.root_ca.private_key_pem

  subject {
    common_name  = var.pki_settings.root_ca_common_name
    organization = "On-Premise GitLab Deployment"
  }

  validity_period_hours = 87600 # 10 Years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]

  lifecycle {
    replace_triggered_by = [terraform_data.pki_rotate]
  }
}

# Vault Server Certificate
resource "tls_private_key" "vault_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "vault_server" {
  private_key_pem = tls_private_key.vault_server.private_key_pem

  subject {
    common_name  = "vault.${var.domain_suffix}"
    organization = "On-Premise GitLab Deployment"
  }

  dns_names = [
    "vault.${var.domain_suffix}",
    "vault",
    "localhost"
  ]

  ip_addresses = concat(
    ["127.0.0.1", local.vault_vip],
    local.vault_node_ips
  )
}

resource "tls_locally_signed_cert" "vault_server" {
  cert_request_pem   = tls_cert_request.vault_server.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 8760 # 1 Year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]

  # Rotate if the Root CA rotates OR if the trigger fires
  lifecycle {
    replace_triggered_by = [
      tls_self_signed_cert.root_ca,
      terraform_data.pki_rotate
    ]
  }
}
