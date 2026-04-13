
variable "databases" {
  description = "Map of databases to create with their properties"
  type = map(object({
    owner      = optional(string, "postgres")
    encoding   = optional(string, "UTF8")
    extensions = optional(list(string), [])
  }))
  default = {}
}

variable "users" {
  description = "Map of users to create with their properties"
  type = map(object({
    password        = string
    login           = optional(bool, true)
    superuser       = optional(bool, false)
    create_database = optional(bool, false)
    roles           = optional(list(string), [])
  }))
  default = {}
}
