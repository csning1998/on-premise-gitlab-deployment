
resource "gitlab_project" "this" {
  name             = var.repository_name
  description      = var.repository_description
  visibility_level = var.visibility

  # Squash and Merge only (mirrors GitHub squash-only policy)
  merge_method  = "ff"
  squash_option = "always"

  # MR Workflow
  remove_source_branch_after_merge = true

  # Features
  issues_access_level = "enabled"
  wiki_access_level   = "disabled"

  initialize_with_readme = false
}


resource "gitlab_branch_protection" "main" {
  project = gitlab_project.this.id
  branch  = "main"

  allowed_to_push  = [{ access_level = "no one" }]
  allowed_to_merge = [{ access_level = "maintainer" }]

  allow_force_push = false
}
