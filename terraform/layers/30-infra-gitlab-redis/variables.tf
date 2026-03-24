
variable "target_clusters" {
  description = "Mapping of logical component roles to physical SSoT cluster names."
  type        = map(string)
}

variable "primary_role" {
  description = "The logical role designated as the primary service entrypoint."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "service_config" {
  description = "Compute topology for Redis service"
  type = map(object({
    role            = string
    network_tier    = string
    base_image_path = string
    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
    }))
  }))
}

variable "ansible_files" {
  description = "Meta configuration of Ansible inventory for Redis service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
