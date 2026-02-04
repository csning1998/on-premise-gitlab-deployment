
variable "harbor_minio_compute" {
  description = "Compute topology for Harbor MinIO service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })
    minio_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
        data_disks = list(object({
          name_suffix = string
          capacity    = number
        }))
      }))
      base_image_path = string
    })
    haproxy_config = object({
      virtual_ip            = string
      frontend_port_api     = number # MinIO API
      frontend_port_console = number # MinIO Console
      backend_port_api      = number
      backend_port_console  = number
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })
}

variable "harbor_minio_infra" {
  description = "Infrastructure config for Harbor MinIO service"
  type = object({
    network = object({
      nat = object({
        gateway = string
        cidrv4  = string
        dhcp = optional(object({
          start = string
          end   = string
        }))
      })
      hostonly = object({
        gateway = string
        cidrv4  = string
      })
    })
    allowed_subnet = string
  })
}

variable "harbor_minio_tenants" {
  description = "Map of buckets to create for Harbor"
  type = map(object({
    user_name      = string
    enable_version = bool
    policy_rw      = bool
  }))
}
