
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
