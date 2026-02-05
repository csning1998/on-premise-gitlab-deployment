
# Strategy for Auto Bootstrapping (by default); 
# Manual Injection is recommand in Production Mode, refer to ./data.tf
resource "tls_private_key" "vault_ca" {
  count     = var.tls_mode == "generated" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "vault_ca" {
  count           = var.tls_mode == "generated" ? 1 : 0
  private_key_pem = tls_private_key.vault_ca[0].private_key_pem

  subject {
    common_name  = "on-premise-gitlab-deployment-root-ca-selfsigned"
    organization = "On-Premise GitLab Deployment"
  }

  validity_period_hours = 365 * 24 # 1 Year
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Output to Files only in Generated Mode
## 1. On-premise CA Cert for Terraform Provider & Ansible  (# )
resource "local_file" "vault_ca" {
  count    = var.tls_mode == "generated" ? 1 : 0
  content  = tls_self_signed_cert.vault_ca[0].cert_pem
  filename = "${var.output_dir}/vault-ca.crt"
}

## 2. Vault Server Certificate for HA Nodes & VIP
resource "tls_private_key" "vault_server" {
  count     = var.tls_mode == "generated" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

## 3. Vault Server Cert & Key
resource "local_file" "vault_server_crt" {
  count    = var.tls_mode == "generated" ? 1 : 0
  content  = tls_locally_signed_cert.vault_server[0].cert_pem
  filename = "${var.output_dir}/vault.crt"
}

resource "local_file" "vault_server_key" {
  count           = var.tls_mode == "generated" ? 1 : 0
  content         = tls_private_key.vault_server[0].private_key_pem
  filename        = "${var.output_dir}/vault.key"
  file_permission = "0600"
}

resource "tls_cert_request" "vault_server" {
  count           = var.tls_mode == "generated" ? 1 : 0
  private_key_pem = tls_private_key.vault_server[0].private_key_pem

  subject {
    common_name  = "vault.iac.local"
    organization = "On-Premise GitLab Deployment"
  }

  dns_names = concat(
    [
      "vault.iac.local",
      "vault",
      "localhost"
    ],
    keys(var.vault_cluster.vault_cluster.nodes)
  )

  ip_addresses = concat(
    [
      "127.0.0.1",
      var.vault_cluster.haproxy_config.virtual_ip
    ],
    [for n in var.vault_cluster.vault_cluster.nodes : n.ip]
  )
}

resource "tls_locally_signed_cert" "vault_server" {
  count              = var.tls_mode == "generated" ? 1 : 0
  cert_request_pem   = tls_cert_request.vault_server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.vault_ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vault_ca[0].cert_pem

  validity_period_hours = 8760 # 1 Year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
