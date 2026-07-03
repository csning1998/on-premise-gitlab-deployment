
output "harbor_gitlab_robot_token" {
  description = "Robot account token for GitLab Registry integration"
  value       = module.harbor_system_config.gitlab_robot_token
  sensitive   = true
}

output "harbor_gitlab_robot_name" {
  description = "Robot account name for GitLab Registry integration"
  value       = module.harbor_system_config.gitlab_robot_name
}

output "harbor_projects" {
  description = "All managed Harbor projects (shared + per-team)"
  value = merge(
    { shared = harbor_project.shared.name },
    { for k in keys(local.team_groups) : "team-${k}" => harbor_project.team[k].name }
  )
}

output "team_robot_vault_paths" {
  description = "Vault KV paths for each team's CI robot credentials"
  value = {
    for k in keys(local.team_groups) :
    k => "secret/${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor/robots/${k}"
  }
}
