# Input & Trigger Configuration

variable "vault_nodes" {
  description = "A map of vault nodes to be configured."
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

variable "haproxy_node" {
  description = "A map of HAProxy nodes to be configured."
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

# Ansible Execution Environment

variable "vm_credentials" {
  description = "Credentials for Ansible to access the target VMs."
  type = object({
    username             = string
    ssh_private_key_path = string
  })
}

variable "infra_credentials" {
  description = "Credentials for Ansible to access the target Databases."
  type = object({
    auth_pass  = string
    stats_pass = string
  })
  sensitive = true
}


# Ansible Playbook Configuration

variable "ansible_config" {
  description = "Configurations for the Ansible execution environment and playbook."
  type = object({
    root_path       = string
    ssh_config_path = string
    extra_vars = object({
      vault_allowed_subnet = string
    })
  })
}

variable "status_trigger" {
  description = "A trigger value that changes when the underlying VMs are provisioned."
  type        = any
}
