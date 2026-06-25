
variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "harbor_helm_config" {
  description = "Configuration for Harbor Helm Chart Deployment"
  type = object({
    version         = string
    namespace       = string
    ingress_class   = string
    tls_secret_name = string
    notary_prefix   = string
  })
}

variable "object_storage_config" {
  description = "Configuration for S3 Object Storage used by Harbor"
  type = object({
    bucket_name = string
    region      = string
  })
}

variable "certificate_config" {
  description = "Configuration for Harbor Ingress Certificate"
  type = object({
    duration     = string
    renew_before = string
  })
  default = {
    duration     = "2160h"
    renew_before = "12h" # Must be less than Vault's 24h declared duration.
  }
}

variable "alloy_version" {
  description = "Grafana Alloy Helm chart version"
  type        = string
  default     = "1.10.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.alloy_version))
    error_message = "alloy_version must be a stable semver string."
  }
}
