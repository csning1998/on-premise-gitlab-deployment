
variable "vault_addr" {
  description = "The address of the Vault server"
  type        = string
}

variable "root_domain" {
  description = "The root domain of the organization"
  type        = string
}

variable "root_ca_common_name" {
  description = "The common name of the root CA"
  type        = string
}

variable "component_roles" {
  description = "Map of Component PKI Roles (Internal/Frontend)"
  type = map(object({
    name            = string
    allowed_domains = list(string)
    max_ttl         = number
    ttl             = number
    ou              = list(string)
  }))
}

variable "dependency_roles" {
  description = "Map of Dependency PKI Roles (Backing Services)"
  type = map(object({
    name            = string
    allowed_domains = list(string)
    max_ttl         = number
    ttl             = number
    ou              = list(string)
  }))
}

variable "auth_backends" {
  description = "Map of Auth Backends to enable"
  type = map(object({
    type = string
    path = string
  }))
  default = {}
}

variable "pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                      = string
    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  })
}
