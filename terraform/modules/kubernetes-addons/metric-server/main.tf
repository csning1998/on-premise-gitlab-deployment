
resource "helm_release" "metrics_server" {
  count = var.helm_config.install ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = var.helm_config.namespace
  version          = var.helm_config.version
  create_namespace = var.helm_config.create_namespace
  cleanup_on_fail  = true

  set = [
    {
      name  = "image.repository"
      value = "${var.helm_config.image_registry}/${var.helm_config.image_repository}/metrics-server"
    },
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}
