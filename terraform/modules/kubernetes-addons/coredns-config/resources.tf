
resource "kubernetes_manifest" "coredns_custom_config" {
  field_manager {
    name            = "terraform-coredns-manager"
    force_conflicts = true
  }

  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "coredns"
      namespace = "kube-system"
      labels = {
        "addonmanager.kubernetes.io/mode" = "EnsureExists"
        "k8s-app"                         = "kube-dns"
      }
    }
    data = {
      Corefile = local.final_corefile
    }
  }
}
