
variable "dev_harbor_compute" {
  description = "Compute topology for Dev Harbor service"
  type = object({
    cluster_identity = object({
      layer_number = number
      service_name = string
      component    = string
    })

    # Dev Harbor Data Nodes
    dev_harbor_system_config = object({
      node = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })
}

variable "dev_harbor_infra" {
  description = "Infrastructure config for Dev Harbor service"
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
