
variable "target_clusters" {
  description = "Map of role to physical cluster names from SSoT."
  type        = map(string)
}

variable "primary_role" {
  description = "Primary role key within target_clusters."
  type        = string
}

variable "service_config" {
  description = "Compute topology per role for Keycloak service."
  type = map(object({
    role            = string
    network_tier    = optional(string, "default")
    base_image_path = string
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
      cpu_mode             = optional(string, null)
    }))
  }))
}
