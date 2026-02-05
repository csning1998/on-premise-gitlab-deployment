
variable "vault_cluster" {
  description = "Vault Cluster (used for SANs)"
  type = object({
    vault_cluster = object({
      nodes = map(object({
        ip = string
      }))
    })
    haproxy_config = object({
      virtual_ip = string
    })
  })
}

variable "output_dir" {
  description = "The absolute path where the generated certificates should be saved."
  type        = string
}

variable "tls_mode" {
  description = "TLS generation mode: 'generated' (Terraform creates keys via tls provider) or 'manual' (Terraform assumes files exist and does nothing)."
  type        = string
  default     = "generated"

  validation {
    condition     = contains(["generated", "manual"], var.tls_mode)
    error_message = "tls_mode must be either 'generated' (Dev) or 'manual' (Prod)."
  }
}
