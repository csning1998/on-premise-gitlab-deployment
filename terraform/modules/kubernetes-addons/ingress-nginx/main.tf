
resource "helm_release" "ingress_nginx" {

  # Ref: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  #
  # Note that the NodePort should be same in the HAProxy configuration 
  # File: 'ansible/roles/35-kubeadm-ha-haproxy/templates/haproxy.cfg.j2'

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.1"
  cleanup_on_fail  = true

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

  depends_on = [helm_release.ingress_nginx]

  metadata {
    name      = "${helm_release.ingress_nginx.name}-controller"
    namespace = helm_release.ingress_nginx.namespace
  }
}
