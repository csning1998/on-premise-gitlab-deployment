
resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = {
      commonName  = var.common_name
      dnsNames    = var.dns_sans
      duration    = var.duration
      renewBefore = var.renew_before
      issuerRef = {
        group = "cert-manager.io"
        kind  = var.issuer_kind
        name  = var.issuer_name
      }
      secretName = var.name
      usages = [
        "digital signature",
        "key encipherment",
        "client auth"
      ]
    }
  }
}
