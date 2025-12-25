
# Declare Harbor certificate (K8s resource)
resource "kubernetes_manifest" "harbor_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "harbor-ingress-cert"
      namespace = "harbor"
    }
    spec = {
      secretName = "harbor-ingress-cert" # Generated Secret Name
      issuerRef = {
        name = "vault-issuer"
        kind = "ClusterIssuer"
      }
      commonName  = var.harbor_hostname
      dnsNames    = [var.harbor_hostname]
      duration    = "2160h" # 90 Days
      renewBefore = "360h"  # 15 Days
    }
  }
}
