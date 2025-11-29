
output "gitlab_robot_token" {
  value     = harbor_robot_account.gitlab_ci.secret
  sensitive = true
}

output "gitlab_robot_name" {
  value = harbor_robot_account.gitlab_ci.full_name
}
