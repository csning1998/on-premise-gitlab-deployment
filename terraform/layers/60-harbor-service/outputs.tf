
output "harbor_gitlab_robot_token" {
  description = "Robot account token for GitLab Registry integration"
  value       = module.harbor_system_config.gitlab_robot_token
  sensitive   = true
}

output "harbor_gitlab_robot_name" {
  description = "Robot account name for GitLab Registry integration"
  value       = module.harbor_system_config.gitlab_robot_name
}
