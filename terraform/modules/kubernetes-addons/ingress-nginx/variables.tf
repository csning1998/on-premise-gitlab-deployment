
variable "helm_config" {
  description = "Ingress Nginx Helm Chart installation configuration"
  type = object({
    install          = bool
    version          = string
    namespace        = string
    create_namespace = bool
    image_registry   = string
    image_repository = string
  })
  default = {
    install          = true
    version          = "4.13.1"
    namespace        = "ingress-nginx"
    create_namespace = true
    image_registry   = "registry.k8s.io"
    image_repository = "ingress-nginx"
  }
}
