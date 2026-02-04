
variable "vault_addr" {
  description = "The address of the Vault server"
  type        = string
}

variable "root_domain" {
  description = "The root domain of the organization"
  type        = string
  default     = "iac.local"
}

variable "vault_pki_path" {
  description = "The path of the PKI backend"
  type        = string
  default     = "pki/prod"
}
