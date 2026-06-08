
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

data "vault_generic_secret" "guest_vm" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/guest_vm"
}

data "vault_kv_secret_v2" "gitaly_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["gitaly"]
}

data "vault_kv_secret_v2" "postgres_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["praefect-patroni"]
}

data "vault_kv_secret_v2" "internal_secrets" {
  provider = vault.production
  mount    = "secret"
  name     = local.credential_paths["gitlab"]["frontend"]
}
