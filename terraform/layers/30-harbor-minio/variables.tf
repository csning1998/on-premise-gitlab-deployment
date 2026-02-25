
variable "service_catalog_name" {
  description = "The name of the service mapped in the Layer 00 Single Source of Truth"
  type        = string
  default     = "harbor"
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "harbor_minio_config" {
  description = "Compute configuration for Harbor MinIO service"
  type = map(object({
    role            = string
    base_image_path = string
    network_tier    = optional(string, "default")
    nodes = map(object({
      ip_suffix = number
      vcpu      = number
      ram       = number
      data_disks = optional(list(object({
        name_suffix = string
        capacity    = number
      })), [])
    }))
  }))
}

variable "harbor_minio_tenants" {
  description = "Map of buckets and users to create for Harbor"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}
