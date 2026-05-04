
# K8s Infrastructure Secrets (Dynamic via Cert-Manager)
module "platform_mtls_certificate" {
  source = "../../modules/kubernetes-addons/platform-mtls-certificate"

  name         = local.postgres_ca
  namespace    = kubernetes_namespace.gitlab_ns.metadata[0].name
  common_name  = local.fqdn_gitlab
  issuer_name  = local.issuer_name
  issuer_kind  = local.issuer_kind
  duration     = local.vault_pki_lease_default
  renew_before = local.vault_pki_lease_agent
}

resource "kubernetes_namespace" "gitlab_ns" {
  metadata {
    name = var.gitlab_helm_config.namespace
  }
}

module "gitlab_core" {
  source = "../../modules/kubernetes-addons/helm-chart-gitlab"
  depends_on = [
    module.platform_mtls_certificate,
    kubernetes_namespace.gitlab_ns
  ]

  # Helm Deployment Configuration
  helm_config = {
    version        = var.gitlab_helm_config.version
    namespace      = kubernetes_namespace.gitlab_ns.metadata[0].name
    timeout        = 1500
    image_registry = local.harbor_registry
    chart_project  = local.helm_chart_project
  }

  # HCL declaration for Reloader annotations
  helm_values_override = local.gitlab_reloader_annotations

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
    issuer_name     = local.issuer_name
    issuer_kind     = local.issuer_kind
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
      ssl_secret = module.platform_mtls_certificate.secret_name
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
