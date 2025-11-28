
# Gitlab Cluster Topology & Configuration

variable "gitlab_cluster_config" {
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
    base_image_path = optional(string, "../../../packer/output/02-base-kubeadm/ubuntu-server-24-02-base-kubeadm.qcow2")
    ha_virtual_ip   = optional(string, "172.16.134.250")
    inventory_file  = optional(string, "inventory-kubeadm-gitlab.yaml")
    service_name    = optional(string, "gitlab")
    registry_host   = optional(string, "172.16.135.250:5000")
    pod_subnet      = optional(string, "10.244.0.0/16")
  })
}

# Gitlab Cluster Infrastructure Network Configuration
variable "gitlab_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Gitlab Cluster."
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
    allowed_subnet    = optional(string, "172.16.134.0/24")
    storage_pool_name = optional(string, "iac-kubeadm-gitlab")
  })
}
