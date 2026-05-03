
variable "enabled" {
  description = "Whether to enable Reloader"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Namespace to deploy Reloader"
  type        = string
  default     = "reloader"
}

variable "chart_version" {
  description = "Reloader Helm Chart version"
  type        = string
  default     = "2.2.11"
}

variable "values_override" {
  description = "Custom Helm values for Reloader"
  type        = any
  default     = {}
}

variable "harbor_oci_config" {
  description = "Configuration for Harbor OCI registry to pull the chart"
  type = object({
    repository = string
  })
}
