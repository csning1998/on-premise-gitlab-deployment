
data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/foundation-vault-bootstrapper" })
}

ephemeral "vault_kv_secret_v2" "gitlab_token" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/project_meta"
}

data "terraform_remote_state" "gemini_api_keys" {
  backend = "http"
  config = {
    address  = "https://gitlab.com/api/v4/projects/84608830/terraform/state/40-gemini-api-keys"
    username = "csning1998"
    password = var.gitlab_token
  }
}

data "terraform_remote_state" "group_topology" {
  backend = "http"
  config = {
    address  = "https://gitlab.com/api/v4/projects/84608830/terraform/state/10-group-topology"
    username = "csning1998"
    password = var.gitlab_token
  }
}
