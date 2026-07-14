
variable "user_name" {
  description = "MinIO IAM user name for the dedicated Prometheus scrape identity"
  type        = string
}

variable "vault_secret_path" {
  description = "Full Vault KV path to store the access key, secret key, and bearer token"
  type        = string
}
