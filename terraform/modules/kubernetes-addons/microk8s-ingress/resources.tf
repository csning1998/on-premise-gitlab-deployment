
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  chart            = "oci://${var.image_registry}/${var.chart_project}/ingress-nginx"
  namespace        = "ingress-system"
  create_namespace = true
  version          = "4.10.0"

  values = [
    yamlencode({
      controller = {
        admissionWebhooks = {
          enabled = false
        }

        ingressClassResource = {
          name    = var.ingress_class_name
          default = true
        }

        kind        = "DaemonSet"
        hostNetwork = true
        dnsPolicy   = "ClusterFirstWithHostNet"

        service = {
          type = "ClusterIP"
        }

        config = {
          "use-proxy-protocol" = "true"
        }
      }
    })
  ]
}
