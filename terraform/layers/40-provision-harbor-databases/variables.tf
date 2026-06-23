

variable "harbor_minio_tenants" {
  description = "Map of buckets and users to create for Harbor"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}

variable "db_init_config" {
  description = "Configuration for Harbor Database Initialization"
  type = object({
    db_name = string # e.g., "registry"
    db_user = string # e.g., "harbor"
  })
}
