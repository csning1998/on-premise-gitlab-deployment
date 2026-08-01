
resource "kubernetes_config_map_v1_data" "calico_config_mtu" {
  metadata {
    name      = "calico-config"
    namespace = "kube-system"
  }

  data = {
    veth_mtu = local.pod_network_mtu - 50
  }

  force = true
}
