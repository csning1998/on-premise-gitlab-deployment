
data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "infra_vars" {
  path = "secret/on-premise-gitlab-deployment/infrastructure"
}
