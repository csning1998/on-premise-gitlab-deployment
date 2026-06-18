
# Infrastructure variables moved to Layer 50.
# GitLab Provisioning variables will be added here as needed.

variable "gitlab_token" {
  description = "GitLab Personal Access Token (PAT) for provisioning. Required after OIDC login is enabled."
  type        = string
  sensitive   = true
  default     = ""
}
