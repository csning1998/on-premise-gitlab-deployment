
/** 
 * Virtual Machine Configuration
 * Variables defining the specifications and credentials for the VMs.
*/

# Module-level variable definitions

variable "vm_config" {
  description = "Fully resolved configuration for nodes, including hardware specs and ordered interfaces."
  type = map(object({
    vcpu            = number
    ram             = number
    base_image_path = string

    interfaces = list(object({
      network_name   = string
      mac            = string
      alias          = optional(string)
      addresses      = optional(list(string), [])
      wait_for_lease = optional(bool, false)
    }))

    data_disks = optional(list(object({
      name_suffix = string
      capacity    = number
    })), [])
  }))
}

variable "credentials" {
  description = "Access credentials for the virtual machines."
  type = object({
    username            = string
    password            = string
    ssh_public_key_path = string
  })
}

variable "libvirt_infrastructure" {
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
    storage_pool_name = string
  })
}

variable "service_segments" {
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
