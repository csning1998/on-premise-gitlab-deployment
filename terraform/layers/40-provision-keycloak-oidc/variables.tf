
variable "oidc_users" {
  description = "Map of users to create in Keycloak with their associated groups"
  type = map(object({
    username   = string
    email      = string
    first_name = string
    last_name  = string
    password   = string
    groups     = list(string)
  }))
  default = {}
}

variable "keycloak_groups" {
  description = "List of groups to create in Keycloak (supports hierarchical paths like 'parent/child')"
  type        = list(string)
  default     = []
}
