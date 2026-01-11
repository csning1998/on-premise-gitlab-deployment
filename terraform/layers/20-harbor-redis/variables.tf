
variable "harbor_redis_compute" {
  description = "Compute topology for Harbor Redis service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
    ha_config = object({
      virtual_ip = string
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string

  })
}

variable "harbor_redis_infra" {
  description = "Infrastructure config for Harbor Redis service"
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
