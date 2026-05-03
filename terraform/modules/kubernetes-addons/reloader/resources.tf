
resource "helm_release" "reloader" {
  count = var.enabled ? 1 : 0
  name  = "reloader"

  # Pointing to internal Harbor OCI synced by Ansible
  repository = var.harbor_oci_config.repository
  chart      = "reloader"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true

  # Using yamlencode to ensure Booleans and structure are correctly typed
  values = [
    yamlencode({
      reloader = {
        watchGlobally = true
        logLevel      = "debug"
        rbac = {
          enabled = true
        }
      }
    }),
    yamlencode(var.values_override)
  ]
}
