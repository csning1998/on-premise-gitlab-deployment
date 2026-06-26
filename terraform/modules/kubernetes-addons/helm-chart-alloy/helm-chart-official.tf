
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
          remote_write_url  = var.alloy_config.remote_write_url
          cluster_label     = var.alloy_config.cluster_label
          tenant_id         = var.alloy_config.tenant_id
          mtls_enabled      = var.alloy_config.mtls_cert_secret_name != null
          vm_static_targets = var.vm_static_targets
        })
      }
      image = {
        registry   = var.helm_config.image_registry
        repository = "${var.helm_config.image_repository}/grafana/alloy"
      }
      clustering = {
        enabled = false
      }
      mounts = {
        extra = var.alloy_config.mtls_cert_secret_name != null ? [
          {
            name      = "alloy-mtls-cert"
            mountPath = "/etc/alloy/mtls"
            readOnly  = true
          }
        ] : []
      }
    }
    controller = {
      type     = "deployment"
      replicas = 1
      volumes = {
        extra = var.alloy_config.mtls_cert_secret_name != null ? [
          {
            name   = "alloy-mtls-cert"
            secret = { secretName = var.alloy_config.mtls_cert_secret_name }
          }
        ] : []
      }
    }
    serviceAccount = { create = true }
    rbac           = { create = true }
  })]
}
