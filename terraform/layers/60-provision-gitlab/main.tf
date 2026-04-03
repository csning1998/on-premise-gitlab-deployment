# terraform/layers/60-gitlab-service/main.tf

resource "kubernetes_namespace" "gitlab_ns" {
  metadata {
    name = var.gitlab_helm_config.namespace
  }
}

module "gitlab_core" {
  source     = "../../modules/kubernetes-addons/helm-chart-gitlab"
  depends_on = [kubernetes_secret.gitlab_postgres_tls]

  # Helm Deployment Configuration
  helm_config = {
    version   = var.gitlab_helm_config.version
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
    timeout   = 600
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
      password = data.vault_kv_secret_v2.gitlab_redis.data["password"]
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
  # Values are sourced from Vault; written by layer 40 to survive layer 60 rebuilds.
  gitlab_secrets = {
    "rails-secret" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitlab_internal.data["rails_secret_key"]
    }
    "shell-secret" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitlab_internal.data["gitlab_shell_secret"]
    }
    "gitaly-secret" = {
      key   = "token"
      value = data.vault_kv_secret_v2.gitlab_internal.data["gitaly_token"]
    }
    "root-password" = {
      key   = "secret"
      value = data.vault_kv_secret_v2.gitlab_internal.data["root_password"]
    }
  }

  ca_bundle = local.ca_bundle_config
}
