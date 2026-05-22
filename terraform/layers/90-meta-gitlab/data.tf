
data "terraform_remote_state" "vault_bootstrapper" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-vault-bootstrapper/terraform.tfstate"
  }
}

ephemeral "vault_kv_secret_v2" "gitlab_token" {
  mount = "secret"
  name  = "on-premise-gitlab-deployment/project_meta"
}
