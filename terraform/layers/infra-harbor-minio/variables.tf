
variable "target_clusters" {
  description = "Mapping of logical component roles to physical SSoT cluster names."
  type        = map(string)
}

variable "primary_role" {
  description = "The logical role designated as the primary service entrypoint."
  type        = string
}


variable "service_config" {
  description = "Compute configuration for Harbor MinIO service"
  type = map(object({
    role            = string
    base_image_path = string
    network_tier    = optional(string, "default")
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
    }))
  }))
}
