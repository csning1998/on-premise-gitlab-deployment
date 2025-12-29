
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.8.3"
    }
  }
}

provider "github" {
  owner = var.github_owner
}
