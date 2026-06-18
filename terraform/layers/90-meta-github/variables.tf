
variable "github_owner" {
  description = "Target GitHub Organization or User Account"
  type        = string
}

variable "repository_name" {
  description = "The name of the repository"
  type        = string
  default     = "on-premise-gitlab-deployment"
}

variable "repository_description" {
  description = "Description of the repository"
  type        = string
}

variable "homepage_url" {
  description = "URL of the canonical source repository (GitLab)"
  type        = string
}

variable "visibility" {
  description = "Visibility of the repository. Can be either 'public' or 'private'. (Non-enterprise GitHub)"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "The visibility must be one of: public or private. (Non-enterprise GitHub)"
  }
}
