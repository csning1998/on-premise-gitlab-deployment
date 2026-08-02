
data "terraform_remote_state" "platform_metadata" {
  backend = "http"
  config = {
    address  = "https://gitlab.com/api/v4/projects/84608830/terraform/state/foundation-metadata"
    username = "csning1998"
    password = var.gitlab_token
  }
}
