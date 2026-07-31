
output "repository_ssh_url" {
  description = "SSH URL of the repository"
  value       = module.baseline.repository_ssh_url
}

output "project_id" {
  description = "The ID of the GitLab project"
  value       = module.baseline.project_id
}
