
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

# Ingress Controller
module "ingress_controller" {
  source = "../../modules/kubernetes-addons/microk8s-ingress"

  ingress_vip        = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
  ingress_class_name = "nginx"
}

# Harbor DB Initialization
module "harbor_db_init" {
  source = "../../modules/configuration/patroni-init"

  pg_host = data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip
  pg_port = data.terraform_remote_state.postgres.outputs.harbor_postgres_haproxy_rw_port

  pg_superuser          = "postgres"
  pg_superuser_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]

  databases = {
    "registry" = {
      owner = "harbor"
    }
  }

  users = {
    "harbor" = {
      password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
      roles    = []
    }
  }
}
