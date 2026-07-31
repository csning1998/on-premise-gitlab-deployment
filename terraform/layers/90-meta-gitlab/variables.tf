
variable "repository_name" {
  description = "The name of the repository"
  type        = string
  default     = "on-premise-gitlab-deployment"
}

variable "repository_description" {
  description = "Description of the repository"
  type        = string
}

variable "visibility" {
  description = "Visibility of the project. Can be 'public', 'private', or 'internal'."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "The visibility must be one of: public, private, or internal."
  }
}

variable "gitlab_token" {
  description = "GitLab Personal Access Token (PAT) with api scope, used only to read csning1998-lab-meta-provision's remote state. The project token in backend-state.json is scoped to this repository alone and cannot reach a different project's state."
  type        = string
  sensitive   = true
}

variable "baseline_module_source" {
  description = "Source address of the project-baseline module in the GitLab Terraform Module Registry."
  type        = string
  const       = true
}

variable "baseline_module_version" {
  description = "Version constraint applied to the project-baseline module fetched from the GitLab Terraform Module Registry."
  type        = string
  const       = true
}
