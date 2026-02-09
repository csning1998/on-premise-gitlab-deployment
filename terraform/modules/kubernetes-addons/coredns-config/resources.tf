
resource "kubernetes_config_map_v1_data" "coredns_custom_config" {

  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  force = true

  data = {
    Corefile = local.final_corefile
  }
}
