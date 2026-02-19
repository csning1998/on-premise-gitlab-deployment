
variable "ansible_config" {
  description = "Ansible execution configuration"
  type = object({
    root_path       = string # e.g. ".../ansible"
    ssh_config_path = string
    playbook_file   = string # e.g. "playbooks/10-vault-core.yaml"
    inventory_file  = string # e.g. "inventory-10-vault-core.yaml"
  })
}

variable "inventory_content" {
  description = "The rendered content of the inventory file (string)"
  type        = string
}

variable "credentials_vm" {
  description = "SSH credentials for Ansible"
  type = object({
    username             = string
    ssh_private_key_path = string
  })
}

variable "extra_vars" {
  description = "Map of sensitive/extra variables to pass to Ansible CLI (-e)"
  type        = map(string)
  default     = {}
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
