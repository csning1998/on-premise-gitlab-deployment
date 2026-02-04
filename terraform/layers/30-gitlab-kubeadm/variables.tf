
variable "gitlab_kubeadm_compute" {
  description = "Compute topology for Gitlab Kubeadm service"
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    kubeadm_config = object({
      # Control Plane Nodes (Map)
      master_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))

      # Worker Nodes (Map)
      worker_nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    haproxy_config = object({
      virtual_ip = string

      # Kubeadm Control Plane defaultly use Master Built-inKeepalived
      nodes = optional(map(object({
        ip   = string
        vcpu = number
        ram  = number
      })), {})
      base_image_path = string
    })

    pod_subnet     = string
    registry_host  = string
    http_nodeport  = number
    https_nodeport = number
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
