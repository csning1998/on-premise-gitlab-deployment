
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

    # Pods are not annotated by default. Setting these annotations enables scrape discovery by Alloy.
    podAnnotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/metrics"
    }
  })]
}

# Full cluster-state data (pod names, replica counts, resource requests, labels) is otherwise
# readable by any pod in this namespace that can reach port 8080, since the annotation above
# has no access control of its own. Restricting ingress to this cluster's own Alloy is what
# makes the annotation-based discovery safe
resource "kubernetes_manifest" "kube_state_metrics_network_policy" {
  depends_on = [helm_release.kube_state_metrics]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "kube-state-metrics-ingress"
      namespace = var.helm_config.namespace
    }
    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name" = "kube-state-metrics"
        }
      }
      policyTypes = ["Ingress"]
      ingress = [{
        from = [{
          namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = var.helm_config.namespace } }
          podSelector       = { matchLabels = { "app.kubernetes.io/name" = "alloy" } }
        }]
        ports = [{ protocol = "TCP", port = 8080 }]
      }]
    }
  }
}
