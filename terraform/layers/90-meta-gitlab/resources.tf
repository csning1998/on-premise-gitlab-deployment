
resource "gitlab_project" "this" {
  name             = var.repository_name
  description      = var.repository_description
  visibility_level = var.visibility

  # Squash and Merge only (mirrors GitHub squash-only policy)
  merge_method  = "ff"
  squash_option = "always"

  # MR Workflow
  remove_source_branch_after_merge         = true
  ci_push_repository_for_job_token_allowed = true # required by prettier-fmt auto-commit

  # Features
  issues_access_level    = "enabled"
  wiki_access_level      = "disabled"
  initialize_with_readme = false
  shared_runners_enabled = false
}

resource "gitlab_branch_protection" "main" {
  project = gitlab_project.this.id
  branch  = "main"

  allowed_to_push  = [{ access_level = "no one" }]
  allowed_to_merge = [{ access_level = "maintainer" }]

  allow_force_push = false
}

resource "gitlab_user_runner" "this" {
  runner_type = "project_type"
  project_id  = gitlab_project.this.id
  description = var.runner_description
  tag_list    = var.runner_tag_list
  locked      = true
}

resource "local_file" "runner_config" {
  filename = "${path.root}/../../../runner-config/config.toml"
  content = templatefile("${path.module}/templates/config.toml.tftpl", {
    runner_name  = var.runner_description
    runner_token = gitlab_user_runner.this.token
    runner_tags  = var.runner_tag_list
  })
  file_permission = "0600"
}
