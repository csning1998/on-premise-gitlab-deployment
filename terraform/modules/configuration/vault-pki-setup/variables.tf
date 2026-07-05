
variable "vault_addr" {
  description = "The address of the Vault server"
  type        = string
}

variable "pki_settings" {
  description = "Global PKI Identity Settings (Root -> Intermediate)"
  type = object({
    root_ca_common_name         = string
    intermediate_ca_common_name = string
  })
}

variable "pki_roles" {
  description = "Unified Map of PKI Roles for all services"
  type = map(object({
    name            = string
    auth_method     = string
    auth_path       = string
    approle_path    = string
    allowed_domains = list(string)
    ou              = list(string)
    max_ttl         = number
    ttl             = number
  }))
}

variable "pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                      = string
    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  })
}
