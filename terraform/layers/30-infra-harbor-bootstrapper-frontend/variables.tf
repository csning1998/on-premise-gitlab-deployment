
variable "target_cluster_name" {
  description = "The physical cluster name target to deploy the service on, retrieved directly from the SSoT mapping."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "harbor_bootstrapper_config" {
  description = "Compute topology for Harbor Bootstrapper service components."
  type = map(object({
    role            = string
    network_tier    = optional(string, "default")
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
  description = "Meta configuration of Ansible inventory for Harbor Bootstrapper service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
