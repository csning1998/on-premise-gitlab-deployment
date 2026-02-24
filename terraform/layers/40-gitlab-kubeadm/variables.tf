
variable "service_catalog_name" {
  description = "The unique service name defined in Layer 00 (e.g. 'vault'). Used to lookup SSoT properties."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "gitlab_kubeadm_config" {
  description = "Compute topology for Gitlab Kubeadm cluster"
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

variable "kubernetes_cluster_configuration" {
  description = "Kubernetes specific cluster parameters"
  type = object({
    pod_subnet = string
  })
}

variable "ansible_files" {
  description = "Meta configuration of Ansible inventory for Vault Core service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
