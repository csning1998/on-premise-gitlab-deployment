
# Keep Calico from flushing externally managed VIP routes.
resource "kubectl_manifest" "felix_configuration" {
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "FelixConfiguration"
    metadata   = { name = "default" }
    spec       = { removeExternalRoutes = var.remove_external_routes }
  })
}
