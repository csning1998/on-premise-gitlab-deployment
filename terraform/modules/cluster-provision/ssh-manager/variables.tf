
variable "config_name" {
  description = "A unique name for this SSH configuration set (e.g., 'kubeadm-cluster')."
  type = object({
    cluster_name    = string
    ssh_config_name = string
  })
}

variable "nodes" {
  description = "A list of node objects to be included in the SSH configs"
  type = list(object({
    key = string
    ip  = string
  }))
}

variable "credentials_vm" {
  description = "Credentials for SSH access to the target VMs."
  type = object({
    username             = string
    ssh_private_key_path = string
  })
  sensitive = true
}

variable "status_trigger" {
  description = "A trigger value that changes when the underlying VMs are recreated."
  type        = any
}
