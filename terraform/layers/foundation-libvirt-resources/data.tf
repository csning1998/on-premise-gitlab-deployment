
locals {
  state = {
    platform_foundation = data.terraform_remote_state.platform_foundation.outputs
  }
}

data "terraform_remote_state" "platform_foundation" {
  backend = "http"
  config = {
    address = "https://gitlab.com/api/v4/projects/84608830/terraform/state/foundation-libvirt-resources"
  }
}
