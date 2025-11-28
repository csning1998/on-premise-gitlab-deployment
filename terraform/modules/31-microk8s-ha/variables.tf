# MicroK8s Cluster Topology & Configuration

variable "microk8s_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      microk8s = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    ha_virtual_ip   = string
    base_image_path = string
    inventory_file  = string
    service_name    = string
  })

  validation {
    condition     = length(var.microk8s_cluster_config.nodes.microk8s) % 2 != 0
    error_message = "The number of MicroK8s nodes for the MicroK8s cluster must be an odd number (1, 3, 5, etc.) to ensure a stable dqlite quorum."
  }

  validation {
    condition     = alltrue([for node in var.microk8s_cluster_config.nodes.microk8s : node.vcpu >= 2 && node.ram >= 4096])
    error_message = "MicroK8s nodes require at least 2 vCPUs and 4096MB RAM to prevent OOM kills."
  }

  validation {
    condition     = alltrue([for node in var.microk8s_cluster_config.nodes.microk8s : can(cidrnetmask("${node.ip}/32"))])
    error_message = "All provided MicroK8s node IP addresses must be valid IPv4 addresses."
  }
}

# Libvirt MicroK8s Cluster Infrastructure Network Configuration

variable "libvirt_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the MicroK8s Cluster."
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
