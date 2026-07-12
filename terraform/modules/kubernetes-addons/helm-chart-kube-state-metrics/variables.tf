
variable "helm_config" {
  description = "Helm chart deployment configuration including OCI registry references"
  type = object({
    version          = string
    namespace        = string
    timeout          = number
    image_registry   = string
    chart_project    = string
    image_repository = string
  })
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.helm_config.version))
    error_message = "helm_config.version must be a stable semver string (e.g. 5.32.0)."
  }
}
