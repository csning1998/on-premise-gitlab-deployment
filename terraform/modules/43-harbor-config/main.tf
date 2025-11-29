
# Public Library for Base Images, which is ususally already existed in Harbor.
# resource "harbor_project" "library" {
#   name   = "library"
#   public = true
# }

# Private Registry for GitLab CI/CD
resource "harbor_project" "gitlab_registry" {
  name   = "gitlab-registry"
  public = false
}

# Robot Account for GitLab CI/CD
resource "harbor_robot_account" "gitlab_ci" {
  name        = "gitlab-ci-robot"
  level       = "project"
  description = "Robot account for GitLab CI/CD integration"

  permissions {
    kind      = "project"
    namespace = harbor_project.gitlab_registry.name

    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "create"
      resource = "tag"
    }
    access {
      action   = "delete"
      resource = "tag"
    }
    access {
      action   = "list"
      resource = "repository"
    }
  }
}

# GC Schedule to clean up untagged images daily at 2:00 AM
resource "harbor_garbage_collection" "gc" {
  schedule        = "0 0 2 * * *"
  delete_untagged = true
}
