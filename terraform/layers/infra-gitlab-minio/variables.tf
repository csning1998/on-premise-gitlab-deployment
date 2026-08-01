
variable "primary_role" {
  description = "The primary role for this layer (e.g. 'minio')."
  type        = string
}

variable "target_clusters" {
  description = "Map of role to physical cluster names."
  type        = map(string)
}


variable "service_config" {
  description = "Compute topology for MinIO service"
  type = map(object({
    role            = string
    network_tier    = string
    base_image_path = string
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
    }))
  }))
}
