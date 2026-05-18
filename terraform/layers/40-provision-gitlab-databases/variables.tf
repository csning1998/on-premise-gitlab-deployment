
variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "gitlab_minio_tenants" {
  description = "Map of buckets and users to create for GitLab"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
    function       = string
  }))
}

variable "extension_drop_cascade" {
  description = "Whether to use DROP CASCADE when destroying PostgreSQL extensions."
  type        = bool
  default     = false
}
