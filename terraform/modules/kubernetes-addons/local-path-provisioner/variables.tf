
variable "helm_config" {
  description = "Local Path Provisioner Helm Chart installation configuration"
  type = object({
    install          = bool
    version          = string
    namespace        = string
    create_namespace = bool
    image_registry          = string
    image_repository        = string
    helper_image_repository = string
  })
  default = {
    install                 = true
    version                 = "0.0.35"
    namespace               = "kube-system"
    create_namespace        = true
    image_registry          = "docker.io"
    image_repository        = "rancher"
    helper_image_repository = "library"
  }
}
