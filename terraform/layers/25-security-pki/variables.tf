
variable "vault_pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                      = string
    default_lease_ttl_seconds = optional(number, 60 * 60 * 24)      # 1 Day
    max_lease_ttl_seconds     = optional(number, 60 * 60 * 24 * 45) # 45 Days
  })
}

variable "environment" {
  description = "Target environment simulation for TLS certificate TTL. "
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}
