
# This list is not read from any remote state.
# Each key must match the tenant_id/cluster_label a L50's Alloy module actually writes with.
# Keep this in sync by hand whenever a tenant is added, renamed, or removed at that layer.
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
