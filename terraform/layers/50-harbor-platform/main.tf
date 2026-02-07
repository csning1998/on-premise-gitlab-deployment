
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"

  k8s_connection = {
    host    = local.k8s_api_endpoint
    ca_cert = local.k8s_cluster_ca
  }

  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  issuer_config = {
    name             = "vault-issuer"                                # The ClusterIssuer name in Microk8s
    issue_path       = "sign"                                        # or "issue", depends on Vault PKI setup
    vault_role_name  = local.vault_role_name                         # The Role name in Vault
    pki_mount_path   = local.vault_pki_path                          # Adjust based on Vault PKI mount
    bound_namespaces = var.trust_engine_config.authorized_namespaces # Whitelist namespaces
    token_policies   = [local.vault_policy_name]                     # The policy created in Layer 20
  }

  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  helm_config = {
    install          = true
    version          = var.cert_manager_config.version
    namespace        = var.cert_manager_config.namespace
    create_namespace = true
  }
}

# Ingress Controller
module "ingress_controller" {
  source = "../../modules/kubernetes-addons/microk8s-ingress"

  ingress_vip        = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
  ingress_class_name = "nginx"
}

# CoreDNS Configuration
module "coredns_config" {
  source = "../../modules/kubernetes-addons/coredns-config"

  hosts = local.dns_hosts
}

# Harbor DB Initialization
module "harbor_db_init" {
  source = "../../modules/configuration/patroni-init"

  pg_host = data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip
  pg_port = data.terraform_remote_state.postgres.outputs.harbor_postgres_haproxy_rw_port

  pg_superuser          = "postgres"
  pg_superuser_password = local.pg_superuser_password

  databases = {
    (var.db_init_config.db_name) = {
      owner = var.db_init_config.db_user
    }
  }

  users = {
    (var.db_init_config.db_user) = {
      password = local.harbor_pg_db_password
      roles    = []
    }
  }
}
