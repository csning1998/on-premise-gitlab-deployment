
module "tigera_calico" {
  source         = "../../modules/kubernetes-addons/tigera-calico"
  pod_subnet     = local.state.kubeadm.kubernetes_config.pod_subnet
  image_registry = local.harbor_registry
  image_path     = local.harbor_quay_proxy
  chart_project  = local.helm_chart_project
  mtu            = local.pod_network_mtu - 50
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
    chart_project    = local.helm_chart_project
  }

  # Ensure CNI is ready before installing Cert-Manager
  depends_on = [module.tigera_calico]
}

module "kubelet_csr_approver" {
  source = "../../modules/kubernetes-addons/kubelet-csr-approver"
  helm_config = {
    install          = true
    version          = var.csr_approver_config.version
    namespace        = var.csr_approver_config.namespace
    create_namespace = false # Already in kube-system
    image_registry   = local.harbor_registry
    image_repository = "${local.harbor_ghcr_proxy}/postfinance"
    chart_project    = local.helm_chart_project
    image_tag        = "v${var.csr_approver_config.version}"
    provider_regex   = local.node_serving_cert_regex
  }
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
    chart_project    = local.helm_chart_project
  }
  depends_on = [module.kubelet_csr_approver]
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
    chart_project    = local.helm_chart_project
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
    chart_project           = local.helm_chart_project
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
    timeout        = 1500
    image_registry = local.harbor_registry
    chart_project  = local.helm_chart_project
  }

  # GitLab Application Configuration
  gitlab_config = {
    hostname = local.fqdn_gitlab
    edition  = "ce"
    dns_sans = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san
  }

  # Trust Engine Integration
  ingress_config = {
    class_name      = var.gitlab_helm_config.ingress_class
    tls_secret_name = var.gitlab_helm_config.tls_secret_name
    issuer_name     = var.trust_engine_config.issuer_name
    issuer_kind     = var.trust_engine_config.issuer_kind
  }

  certificate_config = {
    duration     = local.state.vault_pki.pki_configuration.lease_durations.default
    renew_before = local.state.vault_pki.pki_configuration.lease_durations.agent
  }

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
