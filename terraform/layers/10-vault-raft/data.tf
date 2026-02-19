
data "terraform_remote_state" "topology" {
  backend = "local"
  config = {
    path = "${path.root}/../00-global-topology/terraform.tfstate"
  }
}

data "terraform_remote_state" "central_lb" {
  backend = "local"
  config = {
    path = "${path.root}/../05-central-lb/terraform.tfstate"
  }
}

data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "infra_vars" {
  path = "secret/on-premise-gitlab-deployment/infrastructure"
}
