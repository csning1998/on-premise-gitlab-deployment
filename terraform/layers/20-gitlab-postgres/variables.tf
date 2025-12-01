
variable "gitlab_postgres_compute" {
  description = "Compute topology for Gitlab Postgres service"
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
    etcd_nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
    ha_config = object({
      virtual_ip = string
      stats_port = number
      rw_proxy   = number
      ro_proxy   = number
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string
    inventory_file  = string
  })
}

variable "gitlab_postgres_infra" {
  description = "Infrastructure config for Gitlab Postgres service"
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
