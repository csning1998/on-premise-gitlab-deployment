
variable "minio_tenants" {
  description = "Map of buckets and users to create"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}

variable "vault_secret_path_prefix" {
  description = "Vault path prefix to store generated credentials (e.g., secret/on-premise-gitlab-deployment/harbor)"
  type        = string
}

variable "minio_server_url" {
  description = "The MinIO server URL (e.g. https://172.16.139.250:9000)"
  type        = string
}
