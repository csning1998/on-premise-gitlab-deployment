
variable "harbor_postgres_compute" {
  description = "Compute topology for Harbor Postgres service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Postgres Data Nodes (Map)
    nodes = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    # Etcd Nodes (Map)
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

      # HAProxy Nodes (Map)
      haproxy_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string

  })
}

variable "harbor_postgres_infra" {
  description = "Infrastructure config for Harbor Postgres service"
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
