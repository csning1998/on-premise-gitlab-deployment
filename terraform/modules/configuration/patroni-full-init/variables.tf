
variable "pg_host" {
  description = "PostgreSQL Host or VIP"
  type        = string
}

variable "pg_port" {
  description = "PostgreSQL Port"
  type        = number
  default     = 5432
}

variable "pg_superuser" {
  description = "Superuser username for connection"
  type        = string
  default     = "postgres"
}

variable "pg_superuser_password" {
  description = "Superuser password"
  type        = string
  sensitive   = true
}

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
