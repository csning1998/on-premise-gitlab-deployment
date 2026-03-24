
variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "harbor_minio_tenants" {
  description = "Map of buckets and users to create for Harbor"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}
