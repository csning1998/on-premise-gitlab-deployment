
variable "harbor_microk8s_compute" {
  description = "Compute topology for Harbor MicroK8s service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    microk8s_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    haproxy_config = object({
      virtual_ip = string
      # If not using MetalLB or built-in HA, then the HAProxy node is not mandatory
      nodes = optional(map(object({
        ip   = string
        vcpu = number
        ram  = number
      })), {})
      base_image_path = string
    })
  })
}

variable "harbor_microk8s_infra" {
  description = "Infrastructure config for Harbor MicroK8s service"
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
