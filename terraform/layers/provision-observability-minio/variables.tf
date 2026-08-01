
variable "observability_minio_tenants" {
  description = "Map of buckets and service accounts to create for the observability stack (Mimir and Loki)"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
    function       = string
  }))
}

variable "observability_minio_prometheus_account" {
  description = "Dedicated MinIO IAM user for authenticated Prometheus scraping"
  type = map(object({
    user_name = string
  }))
  default = {
    "observability-minio-prometheus" = {
      user_name = "observability-minio-prometheus"
    }
  }
}
