
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
