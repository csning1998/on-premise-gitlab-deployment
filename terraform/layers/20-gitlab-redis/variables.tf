
# Redis Cluster Compute Configuration

variable "gitlab_redis_compute" {
  description = "Compute topology for Gitlab Redis service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })
    redis_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
    haproxy_config = object({
      virtual_ip = string
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })
}

# Redis Cluster Infrastructure Network Configuration

variable "gitlab_redis_infra" {
  description = "Infrastructure config for Gitlab Redis service"
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
