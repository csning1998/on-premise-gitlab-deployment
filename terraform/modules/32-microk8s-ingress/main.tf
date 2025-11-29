
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
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

        kind = "DaemonSet"

        service = {
          type           = "LoadBalancer"
          loadBalancerIP = var.ingress_vip
        }

        extraArgs = {
          "enable-ssl-passthrough" = "true"
        }
      }
    })
  ]
}
