
variable "ansible_config" {
  description = "Ansible execution configuration"
  type = object({
    root_path       = string # e.g. ".../ansible"
    ssh_config_path = string
    inventory_file  = string # e.g. "inventory-10-vault-core.yaml"
    verbosity       = optional(number, 4)
  })

  validation {
    condition     = var.ansible_config.root_path != ""
    error_message = "root_path must be a non-empty string."
  }
}

variable "inventory_data" {
  description = "The structured inventory data object (from yamldecode of template)"
  type        = any
}

variable "credentials_vm" {
  description = "SSH credentials for Ansible"
  ephemeral   = true
  type = object({
    username             = string
    ssh_private_key_path = string
  })
  # Note: Turn off `sensitive = true` if and only if in development. It must be enabled for production.
  sensitive = true
}

variable "extra_vars" {
  description = "Map of sensitive/extra variables to pass to Ansible CLI (-e)"
  type        = map(string)
  default     = {}
  # Note: Turn off `sensitive = true` if and only if in development. It must be enabled for production.
  sensitive = true
}

variable "pre_run_commands" {
  description = "List of shell commands to execute before running the playbook (e.g., cleanup)"
  type        = list(string)
  default     = []
}

variable "status_trigger" {
  description = "Trigger to re-run the provisioner (usually VM IDs)"
  type        = any
}
