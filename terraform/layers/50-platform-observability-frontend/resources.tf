
resource "kubernetes_secret" "ca_bundle" {
  metadata {
    name      = local.ca_bundle_config.secret_name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    "ca.crt" = local.ca_bundle_config.content
  }
  depends_on = [kubernetes_namespace.monitoring]
}

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
