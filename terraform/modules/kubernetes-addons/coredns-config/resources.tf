
resource "kubernetes_config_map" "coredns_custom_config" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }

  data = {
    Corefile = local.final_corefile
  }
}
