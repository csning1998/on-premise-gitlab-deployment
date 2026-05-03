
resource "github_repository" "this" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.visibility

  # Squash and Merge
  allow_merge_commit = false
  allow_squash_merge = true
  allow_rebase_merge = false

  # PR Workflow
  allow_update_branch    = true
  delete_branch_on_merge = true

  # Features
  has_issues   = true
  has_projects = false
  has_wiki     = false

  # Avoid Terraform trying to override existing .gitignore or LICENSE
  auto_init = false
}
