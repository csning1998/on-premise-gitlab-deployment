
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
  description = "Hierarchical group definitions with parents and attributes."
  type = map(object({
    parent      = optional(string, null)
    attributes  = optional(map(string), {})
    description = optional(string, "")
  }))
  default = {}
}
