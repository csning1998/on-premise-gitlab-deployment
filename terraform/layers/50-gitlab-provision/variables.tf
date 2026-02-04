
variable "vault_skip_verify" {
  description = "Skip Vault TLS verification"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "The name of the service for this layer"
  type        = string
  default     = "gitlab-provision"
}
