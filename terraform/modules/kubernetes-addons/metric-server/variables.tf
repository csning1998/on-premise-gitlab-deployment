
variable "helm_config" {
  description = "Metrics Server Helm Chart installation configuration"
  type = object({
    install          = bool
    version          = string
    namespace        = string
    create_namespace = bool
    image_registry   = string
    image_repository = string
    chart_project    = string
  })
}
