resource "helm_release" "kubelet_csr_approver" {
  count = var.helm_config.install ? 1 : 0

  name             = "kubelet-csr-approver"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/kubelet-csr-approver"
  namespace        = var.helm_config.namespace
  version          = var.helm_config.version
  create_namespace = var.helm_config.create_namespace
  cleanup_on_fail  = true

  set = [
    {
      name  = "image.repository"
      value = "${var.helm_config.image_registry}/${var.helm_config.image_repository}/kubelet-csr-approver"
    },
    {
      name  = "image.tag"
      value = var.helm_config.image_tag
    },
    {
      name  = "provider.regex"
      value = var.helm_config.provider_regex
    }
  ]
}
