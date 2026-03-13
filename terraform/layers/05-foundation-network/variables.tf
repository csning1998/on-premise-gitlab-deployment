
variable "service_catalog_name" {
  description = "The CLB's service catalog name. Used to anchor the network map lookup."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server."
  type        = string
  default     = "https://127.0.0.1:8200"
}
