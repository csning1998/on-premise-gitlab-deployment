
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

variable "extension_drop_cascade" {
  description = "Whether to use DROP CASCADE when destroying Postgres extensions to automatically drop dependent objects."
  type        = bool
  default     = false
}
