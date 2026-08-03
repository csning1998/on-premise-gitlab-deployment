
data "terraform_remote_state" "platform_metadata" {
  backend = "http"
  config = {
    address  = "https://gitlab.com/api/v4/projects/84608830/terraform/state/foundation-metadata"
    username = var.gitlab_username
    password = var.gitlab_token
  }
}
