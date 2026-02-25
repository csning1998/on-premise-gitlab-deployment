
variable "svc_identity" {
  description = "SSoT Extracted Identity containing cluster_name, storage_pool, etc. Used for shared components like Ansible & SSH."
  type = object({
    cluster_name      = string
    storage_pool_name = string
    bridge_name_host  = string
    bridge_name_nat   = string
    node_name_prefix  = string
    ansible_inventory = string
    ssh_config        = string
  })
}

variable "node_identities" {
  description = "A map of component names to their specific SSoT identity block, used to resolve node prefixes generically."
  type = map(object({
    node_name_prefix = string
  }))
}

variable "topology_cluster" {
  description = "Standardized compute topology supporting multi-component architecture."
  type = object({
    storage_pool_name = string

    components = map(object({
      base_image_path = string
      role            = string
      network_tier    = optional(string, "default")

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

variable "network_infrastructure_map" {
  description = "Raw network infrastructure map passed directly from Layer 05 outputs."
  type = map(object({
    network = object({
      nat = object({
        name        = string
        bridge_name = string
        gateway     = string
        cidr        = string
        dhcp        = optional(any)
      })
      hostonly = object({
        name        = string
        bridge_name = string
        gateway     = string
        cidr        = string
      })
    })
    lb_config = optional(any)
  }))

  validation {
    condition = alltrue(flatten([
      for k, v in var.network_infrastructure_map : [
        can(cidrnetmask(v.network.nat.cidr)),
        can(cidrnetmask(v.network.hostonly.cidr))
      ]
    ]))
    error_message = "All network CIDRs must be valid IPv4 CIDR ranges."
  }
}

# Generic Ansible Injections
variable "ansible_inventory_template_file" {
  description = "The filename of the Ansible inventory template to render internally (resolved against shared templates directory)."
  type        = string
}

variable "ansible_template_vars" {
  description = "A generic map of non-sensitive variables customized for the application's inventory rendering."
  type        = any
  default     = {}
}

variable "ansible_extra_vars" {
  description = "A generic map of sensitive variables for the application, merged with common system variables."
  type        = any
  default     = {}
}

variable "ansible_playbook_file" {
  description = "The name of the Ansible playbook file to execute."
  type        = string
}

# Extensibility Flags
variable "use_minio_hypervisor" {
  description = "Flag to determine if the specific hypervisor-kvm-minio module should be used (handles raw block devices for MinIO)"
  type        = bool
  default     = false
}

# System Credentials
variable "credentials_system" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "security_vault_agent_identity" {
  description = "Identity configurations for Vault Agent"
  type = object({
    vault_address = string
    role_id       = string
    secret_id     = string
    role_name     = string
    ca_cert_b64   = string
    common_name   = string
  })
  sensitive = true
  default   = null
}

variable "security_pki_bundle" {
  description = "PKI artifacts passed from vault_pki."
  type        = any
  default     = null
}
