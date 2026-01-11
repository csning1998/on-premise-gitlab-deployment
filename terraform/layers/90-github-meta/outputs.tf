
output "repository_ssh_url" {
  description = "SSH URL of the repository"
  value       = github_repository.this.ssh_clone_url
}

output "ruleset_id" {
  description = "The ID of the applied ruleset"
  value       = github_repository_ruleset.main_protection.ruleset_id
}
