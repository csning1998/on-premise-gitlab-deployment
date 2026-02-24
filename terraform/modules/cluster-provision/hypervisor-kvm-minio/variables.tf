/** 
 * Virtual Machine Configuration
 * Variables defining the specifications and credentials for the VMs.
*/

# Module-level variable definitions

variable "vm_config" {
  description = "All configurations related to the virtual machines being provisioned."
  type = object({
    all_nodes_map = map(object({
      ip              = string
      vcpu            = number
      ram             = number
      base_image_path = string
      network_tier    = string

      # Mount multiple disk at once
      data_disks = optional(list(object({
        name_suffix = string
        capacity    = number
      })), [])
    }))
  })
}

variable "create_networks" {
  description = "Whether to create libvirt_network resources. Set to false if attaching to existing networks (e.g. created by Layer 05)."
  type        = bool
  default     = true
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
  type = map(object({
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
  }))
}
