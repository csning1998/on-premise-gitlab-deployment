
data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "app_vars" {
  path = "secret/on-premise-gitlab-deployment/${var.topology_config.cluster_identity.service_name}/app"
}
