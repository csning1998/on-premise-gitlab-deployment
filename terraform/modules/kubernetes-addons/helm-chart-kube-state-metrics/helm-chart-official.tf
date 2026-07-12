
resource "helm_release" "kube_state_metrics" {
  name             = "kube-state-metrics"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/kube-state-metrics"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = false
  timeout          = var.helm_config.timeout

  values = [yamlencode({
    image = {
      registry   = var.helm_config.image_registry
      repository = "${var.helm_config.image_repository}/kube-state-metrics/kube-state-metrics"
    }

    # Not annotated by default, so Alloy's pod-annotation discovery would otherwise miss it.
    podAnnotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/metrics"
    }
  })]
}
