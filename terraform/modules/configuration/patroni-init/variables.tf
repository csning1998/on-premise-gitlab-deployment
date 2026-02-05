
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
    owner = optional(string, "postgres")
  }))
  default = {}
}

variable "users" {
  description = "Map of users to create with their passwords"
  type = map(object({
    password = string
    roles    = optional(list(string), [])
  }))
  default = {}
  # sensitive = true
}
