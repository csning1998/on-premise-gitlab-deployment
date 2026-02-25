
variable "service_catalog_name" {
  description = "The unique service name defined in Layer 00 (e.g. 'harbor'). Used to lookup SSoT properties."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "harbor_redis_config" {
  description = "Compute topology for Harbor Redis service."
  type = map(object({
    role            = string
    network_tier    = string
    base_image_path = string

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
}

variable "ansible_files" {
  description = "Meta configuration of Ansible inventory for Harbor Redis service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
