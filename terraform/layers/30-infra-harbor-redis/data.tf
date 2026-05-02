
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "volume" {
  backend = "local"
  config = {
    path = "${path.root}/../05-foundation-volume/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../10-shared-load-balancer-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault-frontend/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-vault-approle/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../25-security-pki/terraform.tfstate"
  }
}


data "vault_kv_secret_v2" "guest_vm" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "db_vars" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/harbor/databases"
}
