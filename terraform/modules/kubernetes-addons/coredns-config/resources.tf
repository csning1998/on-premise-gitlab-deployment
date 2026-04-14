
resource "kubernetes_config_map" "coredns_custom_config" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  data = {
    Corefile = local.final_corefile
  }
}
