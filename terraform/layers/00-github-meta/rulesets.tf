
resource "github_repository_ruleset" "main_protection" {
  name        = "Default Branch Governance"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  # Default branch 
  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Emergency Bypass
  bypass_actors {
    actor_type  = "RepositoryRole"
    actor_id    = 5 # Corresponds to the "admin" repository role.
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count = 1
      require_code_owner_review       = true
      dismiss_stale_reviews_on_push   = true
      require_last_push_approval      = true
    }
  }
}
