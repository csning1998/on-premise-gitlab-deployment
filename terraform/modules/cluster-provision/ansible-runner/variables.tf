
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

variable "playbook_paths" {
  description = "Absolute paths to the playbooks to run, supplied by the calling module. A module-relative path.module lookup breaks once this module is fetched from the Terraform Module Registry."
  type        = list(string)

  validation {
    condition     = length(var.playbook_paths) > 0
    error_message = "playbook_paths must contain at least one path."
  }
}

variable "inventory_data" {
  description = "The structured inventory data object (from yamldecode of template)"
  type        = any
}

variable "extra_vars" {
  description = "Map of sensitive/extra variables to pass to Ansible CLI (-e)"
  type        = map(string)
  default     = {}
  # Note: Turn off `sensitive = true` if and only if in development. It must be enabled for production.
  sensitive = true
}

variable "status_trigger" {
  description = "Trigger to re-run the provisioner (usually VM IDs)"
  type        = any
}
