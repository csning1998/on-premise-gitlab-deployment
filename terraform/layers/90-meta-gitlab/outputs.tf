
output "repository_ssh_url" {
  description = "SSH URL of the repository"
  value       = gitlab_project.this.ssh_url_to_repo
}

output "project_id" {
  description = "The ID of the GitLab project"
  value       = gitlab_project.this.id
}
