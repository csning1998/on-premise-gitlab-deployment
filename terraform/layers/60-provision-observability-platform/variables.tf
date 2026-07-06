
variable "mimir_tenants" {
  description = "Mimir tenant IDs and their display names for Grafana datasource provisioning"
  type = map(object({
    display_name = string
  }))
  default = {
    observability = { display_name = "Observability" }
    gitlab        = { display_name = "GitLab" }
    harbor        = { display_name = "Harbor" }
    gitlab-runner = { display_name = "GitLab Runner" }
  }
}
