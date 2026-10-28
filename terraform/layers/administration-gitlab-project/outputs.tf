
output "project_id" {
  description = "Numeric identifier of the project 'on-premise-gitlab-deployment'."
  value       = module.provisioner_gitlab_project.project_id
}
