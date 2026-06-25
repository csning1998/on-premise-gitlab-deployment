
resource "helm_release" "alloy" {
  name             = "alloy"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/alloy"
  version          = var.helm_config.version
  timeout          = var.helm_config.timeout
  namespace        = var.helm_config.namespace
  create_namespace = false

  values = [yamlencode({
    alloy = {
      configMap = {
        content = templatefile("${path.module}/templates/river_config.tftpl", {
          remote_write_url = var.alloy_config.remote_write_url
          cluster_label    = var.alloy_config.cluster_label
          tenant_id        = var.alloy_config.tenant_id
        })
      }
      image = {
        registry   = var.helm_config.image_registry
        repository = "${var.helm_config.image_repository}/grafana/alloy"
      }
      clustering = {
        enabled = false
      }
    }
    controller     = { type = "deployment", replicas = 1 }
    serviceAccount = { create = true }
    rbac           = { create = true }
  })]
}
