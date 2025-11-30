
# 1. Root CA
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = var.common_name_subject
    organization = var.organization
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# 2. Server Certificate
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = var.cert_common_name
    organization = var.organization
  }

  dns_names = concat([var.cert_common_name], var.dns_names)
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 3. Kubernetes Secret
resource "kubernetes_secret" "harbor_tls" {
  metadata {
    name      = var.secret_name
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_locally_signed_cert.server.cert_pem
    "tls.key" = tls_private_key.server.private_key_pem
    "ca.crt"  = tls_self_signed_cert.ca.cert_pem
  }
}
resource "null_resource" "tls_dir" {
  triggers = {
    # This will run whenever the path changes, which is effectively once.
    dir_path = "${path.root}/tls"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/tls"
  }
}

# 4. Export CA for Client Trust
resource "local_file" "ca_cert" {
  depends_on = [null_resource.tls_dir]

  content  = tls_self_signed_cert.ca.cert_pem
  filename = "${path.root}/tls/harbor-ca.crt"
}
