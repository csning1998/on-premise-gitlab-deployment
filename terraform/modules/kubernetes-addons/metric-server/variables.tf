
variable "helm_config" {
  description = "Metrics Server Helm Chart installation configuration"
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
    version          = "3.13.0"
    namespace        = "kube-system"
    create_namespace = true
    image_registry   = "registry.k8s.io"
    image_repository = "metrics-server"
  }
}
