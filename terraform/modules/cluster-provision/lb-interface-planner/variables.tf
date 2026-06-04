
variable "node_config" {
  description = "Load balancer node specifications keyed by node key."
  type = map(object({
    ip_suffix            = number
    vcpu                 = number
    ram                  = number
    base_image_path      = string
    os_disk_capacity_gib = optional(number, 40)
  }))

  validation {
    condition     = length(var.node_config) > 0
    error_message = "At least one LB node must be defined."
  }
}

variable "storage_pool_name" {
  description = "Libvirt storage pool name for VM disks."
  type        = string
}

variable "svc_network" {
  description = "CLB own segment network attributes from SSoT (mac_address, cidr_block)."
  type = object({
    mac_address = string
    cidr_block  = string
  })
}

variable "network_infra" {
  description = "Physical NAT and HostOnly network config for the CLB own segment."
  type = object({
    nat = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      dhcp = optional(object({
        start = string
        end   = string
      }))
      mtu = number
    })
    hostonly = object({
      name        = string
      bridge_name = string
      gateway     = string
      prefix      = number
      mtu         = number
    })
    access_scope = optional(string)
  })
}

variable "svc_network_map" {
  description = "Full topology network map keyed by cluster_name, used for service segment MAC and CIDR resolution."
  type        = any
}

variable "service_segment_names" {
  description = "Ordered list of service segment names (non-CLB) that become additional interfaces on each LB node."
  type        = list(string)
  default     = []
}
