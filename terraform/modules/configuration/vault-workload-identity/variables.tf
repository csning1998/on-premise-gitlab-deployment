
variable "name" {
  description = "The logical name of the workload identity (e.g., gitlab-postgres)"
  type        = string
}

variable "approle_mount_path" {
  description = "The mount path of the AppRole Auth Backend (e.g., 'approle')"
  type        = string
}

variable "vault_role_name" {
  description = "The PKI Role Name defined in vault-pki-setup (e.g., gitlab-postgres-role)"
  type        = string
}

variable "pki_mount_path" {
  description = "The mount path of the PKI backend"
  type        = string
}

variable "token_ttl" {
  description = "The TTL of the generated AppRole token"
  type        = number
  default     = 3600
}

variable "token_max_ttl" {
  description = "The Max TTL of the generated AppRole token"
  type        = number
  default     = 86400
}

variable "extra_policy_hcl" {
  description = "Additional Vault Policy HCL to append (e.g., for secret reading capabilities)"
  type        = string
  default     = ""
}
