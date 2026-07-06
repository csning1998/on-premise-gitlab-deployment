
variable "target_clusters" {
  description = "Map of role to physical cluster names from SSoT."
  type        = map(string)
}

variable "primary_role" {
  description = "Primary role key within target_clusters."
  type        = string
}

variable "vault_dev_endpoint" {
  description = "The address of the Vault server."
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "service_config" {
  description = "Compute topology per role for Vault Core service."
  type = map(object({
    role            = string
    network_tier    = optional(string, "default")
    base_image_path = string
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
    }))
  }))
}
