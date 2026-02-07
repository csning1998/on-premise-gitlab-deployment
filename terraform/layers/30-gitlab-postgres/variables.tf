
variable "gitlab_postgres_compute" {
  description = "Compute topology for Gitlab Postgres service"
  type = object({
    cluster_identity = object({
      layer_number = number
      service_name = string
      component    = string
    })

    # Postgres Data Nodes (Map)
    postgres_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    # Postgres Etcd Nodes (Map)
    etcd_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    haproxy_config = object({
      virtual_ip = string
      stats_port = number
      rw_proxy   = number
      ro_proxy   = number

      # Postgres HAProxy Nodes (Map)
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
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
