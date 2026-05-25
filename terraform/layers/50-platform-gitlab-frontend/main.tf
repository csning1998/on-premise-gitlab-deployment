
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
    kubernetes_namespace.gitlab_ns,
    kubernetes_secret.gitlab_keycloak_oidc
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
    hostname             = local.fqdn_gitlab
    edition              = "ce"
    dns_sans             = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san
    omniauth_secret_name = local.gitlab_config.omniauth_secret_name
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
      host       = local.fqdn_postgres
      port       = local.gitlab_db.port
      password   = local.gitlab_db.password
      username   = local.gitlab_db.username
      database   = local.gitlab_db.database
      ssl_secret = module.platform_mtls_certificate.secret_name
    }

    redis = {
      host     = local.fqdn_redis
      port     = local.redis_port
      password = local.redis_password
      scheme   = "rediss"
    }

    minio = {
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

    gitaly = {
      external_address = local.gitaly_endpoint
    }
  }

  # Internal Secrets of Rails, Gitaly, etc.
  # Sourced persistently from Layer 30 via Vault to support data-safe Greenfield rebuilds
  gitlab_secrets = {
    "rails-secret" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitlab_internal_secrets.data["rails_secret_key"]
    }
    "root-password" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitlab_internal_secrets.data["root_password"]
    }
    "shell-secret" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitaly_secrets.data["gitlab_shell_secret"]
    }
    "gitaly-secret" = {
      key = "token"
      # When Praefect is deployed, GitLab Rails connects to the Praefect VIP using
      # praefect_external_token. When standalone, it connects directly to Gitaly
      # using gitaly_token. The decision mirrors local.gitaly_endpoint.
      value = local.has_praefect ? data.vault_kv_secret_v2.gitaly_secrets.data["praefect_external_token"] : data.vault_kv_secret_v2.gitaly_secrets.data["gitaly_token"]
    }
  }

  gitlab_shell_node_port = local.shell_port
  ca_bundle              = local.ca_bundle_config
}
