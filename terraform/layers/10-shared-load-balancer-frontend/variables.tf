
variable "target_cluster_name" {
  description = "The physical cluster name target to deploy the service on, retrieved directly from the SSoT mapping."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "node_config" {
  description = "Configuration for Load Balancer nodes (resources and IP suffix)."
  type = map(object({
    ip_suffix = number
    vcpu      = number
    ram       = number
  }))
}

variable "base_image_path" {
  description = "The path to the base image for the Load Balancer nodes."
  type        = string
}
