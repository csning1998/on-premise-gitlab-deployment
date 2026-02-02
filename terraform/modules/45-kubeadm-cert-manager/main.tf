
# 1. Install Cert-Manager via Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.19.2"

  # Helm Provider v3 Syntax: List of Objects
  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "webhook.timeoutSeconds"
      value = "30"
    }
  ]

  timeout = 600
}

# 2. ClusterIssuer: Internal SelfSigned
resource "helm_release" "cert_manager_issuers" {

  depends_on = [helm_release.cert_manager]

  name      = "internal-issuer"
  chart     = "${path.module}/assets/raw-chart"
  namespace = "cert-manager"

  values = [
    yamlencode({
      resources = [
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = "k8s-internal-issuer"
          }
          spec = {
            selfSigned = {}
          }
        }
      ]
    })
  ]
}
