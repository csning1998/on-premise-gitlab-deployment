
resource "helm_release" "reloader" {
  count = var.enabled ? 1 : 0
  name  = "reloader"

  # Pointing to internal Harbor OCI synced by Ansible
  repository = var.harbor_oci_config.repository
  chart      = "reloader"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true

  # Using attribute syntax [ { name = ..., value = ... } ] to match project standards
  set = [
    {
      name  = "reloader.watchGlobally"
      value = "true"
    },
    {
      name  = "rbac.enabled"
      value = "true"
    }
  ]

  values = [
    yamlencode(var.values_override)
  ]
}
