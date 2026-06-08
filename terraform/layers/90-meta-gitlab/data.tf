
data "terraform_remote_state" "vault_bootstrapper" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-vault-bootstrapper" })
}

ephemeral "vault_kv_secret_v2" "gitlab_token" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/project_meta"
}
