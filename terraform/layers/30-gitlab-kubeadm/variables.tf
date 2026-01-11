
variable "gitlab_kubeadm_compute" {
  description = "Compute topology for Gitlab Kubeadm service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Control Plane Nodes (Map)
    masters = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    # Worker Nodes (Map)
    workers = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))

    ha_config = object({
      virtual_ip = string

      # Kubeadm Control Plane defaultly use Master Built-inKeepalived
      haproxy_nodes = optional(map(object({
        ip   = string
        vcpu = number
        ram  = number
      })), {})
    })
    pod_subnet      = string
    registry_host   = string
    base_image_path = string

  })
}

variable "gitlab_kubeadm_infra" {
  description = "Infrastructure config for Gitlab Kubeadm service"
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
