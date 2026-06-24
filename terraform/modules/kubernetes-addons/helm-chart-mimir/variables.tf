
variable "helm_config" {
  description = "Helm chart deployment configuration including OCI registry references"
  type = object({
    version               = string
    namespace             = string
    timeout               = number
    image_registry        = string
    chart_project         = string
    image_repository      = string
    dns_resolver          = string
    ca_bundle_secret_name = string
  })
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.helm_config.version))
    error_message = "helm_config.version must be a stable semver string (e.g. 6.0.6)."
  }
}

variable "storage_config" {
  description = "External MinIO S3 backend connection and per-bucket credentials for each Mimir storage subsystem"
  sensitive   = true
  type = object({
    endpoint                = string
    blocks_access_key       = string
    blocks_secret_key       = string
    ruler_access_key        = string
    ruler_secret_key        = string
    alertmanager_access_key = string
    alertmanager_secret_key = string
    blocks_bucket           = string
    ruler_bucket            = string
    alertmanager_bucket     = string
  })
}
