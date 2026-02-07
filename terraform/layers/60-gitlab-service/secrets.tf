
resource "random_password" "gitlab_internal" {
  for_each = local.gitlab_secrets
  length   = each.value.length
  special  = each.value.special
}

resource "kubernetes_secret" "gitlab_internal" {
  for_each = local.gitlab_secrets
  metadata {
    name      = "gitlab-${each.key}"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    (each.value.key) = random_password.gitlab_internal[each.key].result
  }
}

resource "vault_generic_secret" "gitlab_internal_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key      = random_password.gitlab_internal["rails-secret"].result
    gitlab_shell_secret   = random_password.gitlab_internal["shell-secret"].result
    gitaly_token          = random_password.gitlab_internal["gitaly-secret"].result
    initial_root_password = random_password.gitlab_internal["root-password"].result
  })
}
