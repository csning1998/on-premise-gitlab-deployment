
variable "cluster_name" {
  description = "The name of the MicroK8s cluster (e.g., 30-harbor-microk8s)"
  type        = string
}

variable "service_vip" {
  description = "The Virtual IP address of the MicroK8s cluster"
  type        = string
}

variable "topology_cluster" {
  description = "The topology configuration for the cluster extracted from Layer 00"
  type = object({
    cluster_name      = string
    storage_pool_name = string
    components = map(object({
      role            = string
      base_image_path = string
      network_tier    = string
      nodes = map(object({
        ip_suffix = number
        vcpu      = number
        ram       = number
        data_disks = optional(list(object({
          name_suffix = string
          capacity    = number
        })), [])
      }))
    }))
  })
}

variable "network_bindings" {
  description = "Network binding mappings from Layer 05. Key is the network tier."
  type = map(object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  }))
}

variable "network_parameters" {
  description = "Detailed network characteristics from Layer 05. Key is the network tier."
  type = map(object({
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
    network_access_scope = string
  }))
}

variable "credentials_system" {
  description = "System credentials for SSH and VM operations (Root Level)"
  type = object({
    username             = string
    password             = string
    ssh_private_key_path = string
    ssh_public_key_path  = string
  })
  sensitive = true
}

variable "credentials_vault_agent" {
  description = "Vault agent credentials for obtaining PKI certificates"
  type = object({
    role_id       = string
    secret_id     = string
    role_name     = string
    ca_cert_b64   = string
    vault_address = string
    common_name   = string
  })
  sensitive = true
}

variable "security_pki_bundle" {
  description = "Initial PKI certificate bundle (optional, fallback if Vault agent fails)"
  type = object({
    ca_cert     = string
    server_cert = string
    server_key  = string
  })
  sensitive = true
  default   = null
}

variable "ansible_files" {
  description = "Ansible playbooks and templates configuration"
  type = object({
    inventory_template_file = string
    playbook_file           = string
  })
}
