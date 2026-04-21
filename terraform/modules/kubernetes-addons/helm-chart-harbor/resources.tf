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
