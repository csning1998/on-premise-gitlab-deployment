
# 1. Root CA
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = var.rsa_bits
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = var.common_name_subject
    organization = var.organization
  }

  validity_period_hours = var.validity_period
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# 2. Server Certificate for Postgres
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = var.rsa_bits
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = var.common_name
    organization = var.organization
  }

  ip_addresses = var.server_ips
  dns_names    = var.server_dns_names
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.validity_period

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 3. Client Certificate for Harbor/Terraform
resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = var.rsa_bits
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = var.client_common_name
    organization = var.organization
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.validity_period

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth", # for mTLS Client Authentication
  ]
}
