
/** 
 * Virtual Machine Configuration
 * Variables defining the specifications and credentials for the VMs.
*/

# Module-level variable definitions

variable "create_networks" {
  description = "Whether to create network resources inside the module. Set to false if networks are pre-provisioned by Layer 05 root."
  type        = bool
  default     = true
}

variable "lb_cluster_vm_config" {
  description = "Fully resolved configuration for nodes, including hardware specs and ordered interfaces."
  type = object({
    storage_pool_name = string
    nodes = map(object({
      vcpu            = number
      ram             = number
      base_image_path = string
      interfaces = list(object({
        network_name = string
        mac          = string
        alias        = optional(string)
        addresses    = optional(list(string), [])
      }))
      data_disks = optional(list(object({
        name_suffix = string
        capacity    = number
      })), [])
    }))
  })
}

variable "lb_cluster_network_config" {
  description = "All configurations for Libvirt-managed networks and storage."
  type = object({
    network = object({
      nat = object({
        name_network = string
        name_bridge  = string
        mode         = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = optional(string)
            end   = optional(string)
          }))
        })
      })
      hostonly = object({
        name_network = string
        name_bridge  = string
        mode         = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = optional(string)
            end   = optional(string)
          }))
        })
      })
    })
  })
}

variable "lb_cluster_service_segments" {
  description = "List of network segments for the Load Balancer."
  type = list(object({
    name        = string
    bridge_name = string
    cidr        = optional(string)
    vrid        = optional(number)
    vip         = optional(string)
    node_ips    = optional(map(string))
  }))
}

variable "network_infrastructure" {
  description = "Map of all networks (HostOnly and NAT) to be created by this module."
  type = map(object({
    hostonly = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
    })
    nat = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      dhcp        = optional(any)
    })
    access_scope = optional(string)
  }))
}

variable "credentials_vm" {
  description = "Credentials for SSH access to the target VMs."
  type = object({
    username            = string
    password            = string
    ssh_public_key_path = string
  })
}

