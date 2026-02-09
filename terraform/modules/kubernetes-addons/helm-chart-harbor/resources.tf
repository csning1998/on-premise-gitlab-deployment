
# 1. Harbor PKI Certificate
resource "kubernetes_manifest" "harbor_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.ingress_config.tls_secret_name
      namespace = var.helm_config.namespace
    }
    spec = {
      secretName = var.ingress_config.tls_secret_name

      issuerRef = {
        name = var.ingress_config.issuer_name
        kind = var.ingress_config.issuer_kind
      }

      privateKey = {
        algorithm = "RSA"
        encoding  = "PKCS1"
        size      = 2048
      }

      dnsNames    = [var.harbor_config.hostname]
      duration    = var.certificate_config.duration
      renewBefore = var.certificate_config.renew_before
    }
  }
}

# 1. Module creates Secret
resource "kubernetes_secret" "harbor_ca_bundle" {
  metadata {
    name      = var.ca_bundle.name
    namespace = var.helm_config.namespace
  }

  data = {
    "ca.crt" = var.ca_bundle.content
  }
}
