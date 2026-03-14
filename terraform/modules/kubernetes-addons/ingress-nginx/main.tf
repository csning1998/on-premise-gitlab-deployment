
resource "helm_release" "ingress_nginx" {
  count = var.helm_config.install ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = var.helm_config.namespace
  create_namespace = var.helm_config.create_namespace
  version          = var.helm_config.version
  cleanup_on_fail  = true

  set = [
    {
      name  = "controller.image.registry"
      value = var.helm_config.image_registry
    },
    {
      name  = "controller.image.image"
      value = "${var.helm_config.image_repository}/controller"
    },
    {
      name  = "controller.admissionWebhooks.patch.image.registry"
      value = var.helm_config.image_registry
    },
    {
      name  = "controller.admissionWebhooks.patch.image.image"
      value = "${var.helm_config.image_repository}/kube-webhook-certgen"
    }
  ]

  values = [
    yamlencode({
      controller = {
        service = {
          type = "NodePort"
          nodePorts = {
            http  = 30080
            https = 30443
          }
        }
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
        # Ensure Pod only runs on nodes with IP (usually doesn't need special setting, but can be a safety measure)
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        values   = ["ingress-nginx"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }
    })
  ]
}

# Search for Ingress NGINX Controller Service created by Helm Chart
data "kubernetes_service_v1" "ingress_nginx_controller" {
  count = var.helm_config.install ? 1 : 0

  depends_on = [helm_release.ingress_nginx]

  metadata {
    name      = "${helm_release.ingress_nginx[0].name}-controller"
    namespace = helm_release.ingress_nginx[0].namespace
  }
}
