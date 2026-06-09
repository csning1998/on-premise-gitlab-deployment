
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

variable "runner_description" {
  description = "Display name of the project runner registered to this repository"
  type        = string
  default     = "local-podman-runner"
}

variable "runner_tag_list" {
  description = "Tag list for job matching; jobs must declare matching tags to run on this runner"
  type        = list(string)
  default     = ["podman", "local"]
}
