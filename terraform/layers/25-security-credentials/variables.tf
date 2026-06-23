
variable "minio_root_user" {
  description = "MinIO root username (human-managed, shared by GitLab and Harbor MinIO)."
  type        = string
  sensitive   = true
}

variable "keycloak_admin_user" {
  description = "Keycloak admin username (human-managed)."
  type        = string
  sensitive   = true
}

variable "keycloak_db_user" {
  description = "Keycloak database username (human-managed)."
  type        = string
  sensitive   = true
}

variable "gitlab_enable_praefect" {
  description = "Whether the GitLab topology runs Praefect. Controls generation of praefect-only secrets."
  type        = bool
  default     = true
}

variable "grafana_admin_user" {
  description = "Grafana admin username (human-managed)."
  type        = string
  sensitive   = true
}
