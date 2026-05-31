
variable "helm_config" {
  type = object({
    install          = bool
    version          = string
    namespace        = string
    create_namespace = bool
    image_registry   = string
    image_repository = string
    chart_project    = string
  })
  description = "Detailed configuration for deploying External Secrets Operator helm chart"
}

variable "values_override" {
  type        = any
  default     = {}
  description = "Map of values to override in helm release"
}
