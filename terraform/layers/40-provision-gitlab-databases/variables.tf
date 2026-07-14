
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

variable "gitlab_minio_prometheus_account" {
  description = "Dedicated MinIO IAM user for authenticated Prometheus scraping"
  type = map(object({
    user_name = string
  }))
  default = {
    "gitlab-minio-prometheus" = {
      user_name = "gitlab-minio-prometheus"
    }
  }
}
