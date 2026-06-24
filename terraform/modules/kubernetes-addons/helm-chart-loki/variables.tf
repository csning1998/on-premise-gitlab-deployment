
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
    error_message = "helm_config.version must be a stable semver string (e.g. 17.4.10)."
  }
}

variable "storage_config" {
  description = "External MinIO S3 backend connection and bucket configuration for Loki chunk, ruler, and admin storage"
  sensitive   = true
  type = object({
    endpoint      = string
    access_key    = string
    secret_key    = string
    chunks_bucket = string
    ruler_bucket  = string
    admin_bucket  = string
  })
}
