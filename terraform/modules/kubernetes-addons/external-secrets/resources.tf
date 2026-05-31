
resource "helm_release" "external_secrets" {
  count = var.helm_config.install ? 1 : 0
  name  = "external-secrets"

  # Fully compatible OCI structure to pull 'oci://<registry>/helm-charts/external-secrets'
  repository = "oci://${var.helm_config.image_registry}"
  chart      = "${var.helm_config.chart_project}/external-secrets"
  version    = var.helm_config.version
  namespace  = var.helm_config.namespace

  create_namespace = var.helm_config.create_namespace

  # Auto-inject offline proxy cache registries inside the module to avoid user redundancy
  values = [
    yamlencode(merge(
      {
        image = {
          repository = "${var.helm_config.image_registry}/${var.helm_config.image_repository}"
        }
        webhook = {
          image = {
            repository = "${var.helm_config.image_registry}/${var.helm_config.image_repository}"
          }
        }
        certController = {
          image = {
            repository = "${var.helm_config.image_registry}/${var.helm_config.image_repository}"
          }
        }
      },
      var.values_override
    ))
  ]
}
