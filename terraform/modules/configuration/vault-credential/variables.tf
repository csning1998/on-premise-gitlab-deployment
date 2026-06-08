
variable "vault_kv_namespace" {
  description = "Project-level Vault KV namespace prefix (e.g. on-premise-gitlab-deployment)"
  type        = string
}

variable "domain" {
  description = "Vault secret domain (e.g. gitlab, harbor, keycloak, harbor-bootstrapper)"
  type        = string
}

variable "component" {
  description = "Vault secret component within the domain (e.g. postgres, redis, minio, server, app)"
  type        = string
}

variable "generate" {
  description = "Map of secret key names to password generation parameters"
  type = map(object({
    length  = number
    special = optional(bool, false)
  }))
  default = {}
}

variable "static" {
  description = "Static key-value pairs merged into the same Vault secret (e.g. usernames)"
  type        = map(string)
  default     = {}
  sensitive   = true
}
