
variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "primary_role" {
  description = "The primary role for this layer (e.g. 'microk8s')."
  type        = string
}

variable "target_clusters" {
  description = "A map that matches roles to the cluster name defined in Layer 00."
  type        = map(string)
}

variable "service_config" {
  description = "Compute topology for Harbor Microk8s cluster"
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
  description = "Meta configuration of Ansible inventory for Microk8s service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
