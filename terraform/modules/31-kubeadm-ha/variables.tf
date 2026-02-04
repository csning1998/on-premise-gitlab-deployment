
variable "topology_config" {
  description = "Standardized compute topology configuration for Kubeadm HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Control Plane Nodes (Map)

    kubeadm_config = object({
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

    # Kubeadm Specific Configuration
    pod_subnet     = string # e.g. "10.244.0.0/16"
    registry_host  = string # e.g. "172.16.135.250:5000"
    http_nodeport  = number # e.g. 30080
    https_nodeport = number # e.g. 30443
  })

  # Master Etcd Quorum
  validation {
    condition     = length(var.topology_config.kubeadm_config.master_nodes) % 2 != 0
    error_message = "Kubeadm Master node count must be an odd number (1, 3, 5...) to ensure a stable Etcd quorum."
  }

  # At least need one Worker node
  validation {
    condition     = length(var.topology_config.kubeadm_config.worker_nodes) > 0
    error_message = "At least one Worker node is required for a functional cluster."
  }

  # VIP format check
  validation {
    condition     = can(cidrnetmask("${var.topology_config.haproxy_config.virtual_ip}/32"))
    error_message = "The High Availability Virtual IP (VIP) must be a valid IPv4 address."
  }

  # Master node specification (At least 2vCPU/4GB)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.kubeadm_config.master_nodes :
      node.vcpu >= 2 && node.ram >= 4096
    ])
    error_message = "Control Plane nodes require at least 2 vCPUs and 4096MB RAM."
  }

  # Worker node specification (At least 2vCPU/4GB)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.kubeadm_config.worker_nodes :
      node.vcpu >= 2 && node.ram >= 4096
    ])
    error_message = "Worker nodes require at least 2 vCPUs and 4096MB RAM."
  }

  # Pod Subnet CIDR format check
  validation {
    condition     = can(cidrnetmask(var.topology_config.pod_subnet))
    error_message = "Pod Subnet must be a valid CIDR block."
  }
}

variable "infra_config" {
  description = "Standardized infrastructure network configuration."
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

  validation {

    # Network CIDR format check
    condition = alltrue([
      can(cidrnetmask(var.infra_config.network.nat.cidrv4)),
      can(cidrnetmask(var.infra_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.infra_config.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}
