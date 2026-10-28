
variable "github_owner" {
  description = "Specifies the GitHub account or organization login hosting the mirrored repository."
  type        = string
  default     = "csning1998"

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_owner))
    error_message = "github_owner must be a GitHub login of 1 to 39 characters. A hyphen must not be the first or last character."
  }
}
