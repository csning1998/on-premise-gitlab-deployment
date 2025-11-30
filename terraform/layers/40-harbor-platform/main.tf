
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

module "ingress_controller" {
  source = "../../modules/32-microk8s-ingress"

  ingress_vip        = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
  ingress_class_name = "nginx"
}

module "harbor_tls" {
  source = "../../modules/42-harbor-tls"

  cert_common_name = var.harbor_hostname
  namespace        = kubernetes_namespace.harbor.metadata[0].name
  secret_name      = "harbor-ingress-tls"

  depends_on = [kubernetes_namespace.harbor]
}

module "harbor_db_init" {
  source = "../../modules/41-harbor-postgres-init"

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

module "harbor_config" {
  source     = "../../modules/43-harbor-config"
  depends_on = [helm_release.harbor] # Should be after Harbor Helm Chart Pod Ready
}
