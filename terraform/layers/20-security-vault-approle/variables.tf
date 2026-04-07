
variable "vault_dev_addr" {
  description = "The address of the bootstrap dev Vault"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "custom_vault_policies" {
  description = "Map of path-based policy rules"
  type = map(object({
    capabilities = list(string)
  }))
  default = {}
}
