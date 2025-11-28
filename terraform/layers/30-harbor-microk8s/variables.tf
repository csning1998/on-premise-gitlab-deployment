# MicroK8s Cluster Topology & Configuration

variable "harbor_cluster_config" {
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
    base_image_path = optional(string, "../../../packer/output/03-base-microk8s/ubuntu-server-24-03-base-microk8s.qcow2")
    ha_virtual_ip   = optional(string, "172.16.135.250")
    inventory_file  = optional(string, "inventory-microk8s-harbor.yaml")
    service_name    = optional(string, "harbor")
  })
}

# MicroK8s Cluster Infrastructure Network Configuration

variable "harbor_infrastructure" {
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
    allowed_subnet    = optional(string, "172.16.135.0/24")
    storage_pool_name = optional(string, "iac-microk8s-harbor")
  })
}
