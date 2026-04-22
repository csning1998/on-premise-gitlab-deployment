
module "tigera_calico" {
  source         = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet     = local.state.kubeadm.kubernetes_config.pod_subnet
  image_registry = local.harbor_registry
  image_path     = local.harbor_quay_proxy
}

# [REFACTORED] Trust Engine Integration
module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"
  providers = {
    vault = vault.production
  }

  # 1. K8s Cluster Connection (for Vault to call back)
  api_server_connection = {
    host    = local.api_endpoint
    ca_cert = local.cluster_ca
  }

  # 2. Vault Connection (for Cert-Manager to authenticate)
  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = local.vault_auth_path
  }

  # 3. Issuer Configuration (The "Contract" between K8s and Vault)
  issuer_config = {
    name             = var.trust_engine_config.issuer_name
    bound_namespaces = var.trust_engine_config.authorized_namespaces
    issue_path       = "sign"
    vault_role_name  = local.vault_role_name
    pki_mount_path   = local.vault_pki_path
    token_policies   = [local.vault_policy_name]
  }

  # 4. Reviewer Identity (The entity that validates tokens)
  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  # 5. Helm Chart Installation
  helm_config = {
    install          = true
    version          = var.cert_manager_config.version
    namespace        = var.cert_manager_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_quay_proxy}/jetstack"
    chart_proxy      = local.harbor_quay_proxy
  }

  # Ensure CNI is ready before installing Cert-Manager
  depends_on = [module.tigera_calico]
}

module "metric_server" {
  source = "../../modules/kubernetes-addons/metric-server"
  helm_config = {
    install          = true
    version          = var.metric_server_config.version
    namespace        = var.metric_server_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/metrics-server"
  }
  depends_on = [module.platform_trust_engine]
}

module "ingress_nginx" {
  source = "../../modules/kubernetes-addons/ingress-nginx"
  helm_config = {
    install          = true
    version          = var.ingress_nginx_config.version
    namespace        = var.ingress_nginx_config.namespace
    create_namespace = true
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_k8s_proxy}/ingress-nginx"
  }
  depends_on = [module.platform_trust_engine]
}

module "storage_local_path" {
  source = "../../modules/kubernetes-addons/local-path-provisioner"
  helm_config = {
    install                 = true
    version                 = var.local_path_config.version
    namespace               = var.local_path_config.namespace
    create_namespace        = true
    image_registry          = local.harbor_registry
    image_repository        = "${local.harbor_docker_proxy}/rancher"
    helper_image_repository = "${local.harbor_docker_proxy}/library"
  }
  depends_on = [module.tigera_calico]
}

# CoreDNS Configuration
module "coredns_config" {
  source     = "../../modules/kubernetes-addons/coredns-config"
  depends_on = [module.tigera_calico]

  hosts = local.dns_hosts
}

# terraform/layers/60-gitlab-service/main.tf

resource "kubernetes_namespace" "gitlab_ns" {
  metadata {
    name = var.gitlab_helm_config.namespace
  }
}

module "gitlab_core" {
  source = "../../modules/kubernetes-addons/helm-chart-gitlab"
  depends_on = [
    kubernetes_secret.gitlab_postgres_tls,
    kubernetes_namespace.gitlab_ns,
    module.coredns_config,
    module.platform_trust_engine,
    module.ingress_nginx
  ]

  # Helm Deployment Configuration
  helm_config = {
    version        = var.gitlab_helm_config.version
    namespace      = kubernetes_namespace.gitlab_ns.metadata[0].name
    timeout        = 900
    image_registry = local.harbor_registry
  }

  # GitLab Application Configuration
  gitlab_config = {
    hostname = local.fqdn_gitlab
    edition  = "ce"
    # Root Password
  }

  # Trust Engine Integration
  ingress_config = {
    class_name      = var.gitlab_helm_config.ingress_class
    tls_secret_name = var.gitlab_helm_config.tls_secret_name
    issuer_name     = local.issuer_name # "vault-issuer" from Layer 50
    issuer_kind     = local.issuer_kind # "ClusterIssuer"
  }

  certificate_config = var.certificate_config

  image_registry = {
    registry   = local.gitlab_image_registry
    repository = local.gitlab_image_repository
  }

  # External Services Connection
  external_services = {
    postgres = {
      host       = local.gitlab_db.host
      port       = local.gitlab_db.port
      password   = local.gitlab_db.password
      username   = local.gitlab_db.username
      database   = local.gitlab_db.database
      ssl_secret = kubernetes_secret.gitlab_postgres_tls.metadata[0].name
    }

    redis = {
      host     = local.redis_vip
      port     = local.redis_port
      password = local.state.provision_databases.redis_connection_info.password
      scheme   = "rediss"
    }

    minio = {
      ip         = local.minio_vip
      hostname   = local.fqdn_minio
      endpoint   = local.minio_address
      access_key = ""
      secret_key = ""
      region     = local.s3_region
      buckets = {
        for func_key, bucket_name in local.minio_function_map : func_key => {
          name       = bucket_name
          access_key = data.vault_kv_secret_v2.gitlab_s3[func_key].data["access_key"]
          secret_key = data.vault_kv_secret_v2.gitlab_s3[func_key].data["secret_key"]
        }
      }
    }
  }

  # Internal Secrets of Rails, Gitaly, etc.
  # Values are sourced from local random resources to avoid circular dependencies
  gitlab_secrets = {
    "rails-secret" = {
      key   = "secret"
      value = random_password.gitlab_internal["rails-secret"].result
    }
    "shell-secret" = {
      key   = "secret"
      value = random_password.gitlab_internal["shell-secret"].result
    }
    "gitaly-secret" = {
      key   = "token"
      value = random_password.gitlab_internal["gitaly-secret"].result
    }
    "root-password" = {
      key   = "secret"
      value = random_password.gitlab_internal["root-password"].result
    }
  }

  ca_bundle = local.ca_bundle_config
}
