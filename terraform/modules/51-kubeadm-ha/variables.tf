
# Kubeadm Cluster Topology & Configuration

variable "kubeadm_cluster_config" {
  description = "Define all nodes including virtual hardware resources"
  type = object({
    cluster_name = string
    nodes = object({
      masters = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      workers = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = string
    ha_virtual_ip   = string
    inventory_file  = string
    service_name    = string
    registry_host   = string
    pod_subnet      = string
  })

  validation {
    condition     = length(var.kubeadm_cluster_config.nodes.masters) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }

  validation {
    condition     = length(var.kubeadm_cluster_config.nodes.workers) > 0
    error_message = "At least one worker node is required to run the Kubeadm cluster."
  }

  validation {
    condition     = alltrue([for node in var.kubeadm_cluster_config.nodes.masters : node.vcpu >= 2])
    error_message = "Kubeadm Master nodes require at least 2 vCPUs."
  }

  validation {
    condition     = length(var.kubeadm_cluster_config.nodes.masters) == 1 || (var.kubeadm_cluster_config.ha_virtual_ip != "")
    error_message = "A High Availability Control Plane requires a valid Virtual IP (ha_virtual_ip)."
  }

  validation {
    condition     = alltrue([for node in var.kubeadm_cluster_config.nodes.masters : can(cidrnetmask("${node.ip}/32"))])
    error_message = "All Master node IPs must be valid IPv4 addresses."
  }

  validation {
    condition     = alltrue([for node in var.kubeadm_cluster_config.nodes.workers : can(cidrnetmask("${node.ip}/32"))])
    error_message = "All Worker node IPs must be valid IPv4 addresses."
  }

  validation {
    condition     = can(cidrnetmask(var.kubeadm_cluster_config.pod_subnet))
    error_message = "Pod subnet must be a valid CIDR block."
  }

  # TODO: Add validation for registry_host after Harbor is implemented.
  # validation {
  #   condition     = can(cidrnetmask(split(":", var.kubeadm_cluster_config.registry_host)[0]))
  #   error_message = "Registry host must be a valid IPv4 address with optional port."
  # }
}

# Kubeadm Cluster Infrastructure Network Configuration

variable "libvirt_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Kubeadm Cluster."
  type = object({
    network = object({
      nat = object({
        name_network = string
        name_bridge  = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
      hostonly = object({
        name_network = string
        name_bridge  = string

        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
    })
    allowed_subnet    = string
    storage_pool_name = string
  })
}
