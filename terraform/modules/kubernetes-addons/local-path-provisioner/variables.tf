
variable "helm_config" {
  description = "Local Path Provisioner Helm Chart installation configuration"
  type = object({
    install                 = bool
    version                 = string
    namespace               = string
    create_namespace        = bool
    image_registry          = string
    image_repository        = string
    helper_image_repository = string
    chart_project           = string
  })
}
