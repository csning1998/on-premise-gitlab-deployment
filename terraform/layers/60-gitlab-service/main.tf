
# terraform/layers/60-gitlab-service/main.tf

module "gitlab_core" {
  source = "../../modules/kubernetes-addons/helm-chart-gitlab"

  # Helm Deployment Configuration
  helm_config = {
    version   = var.gitlab_helm_config.version
    namespace = var.gitlab_helm_config.namespace
    timeout   = 600
  }

  # GitLab Application Configuration
  gitlab_config = {
    hostname = local.gitlab_hostname
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

  # External Services Connection
  external_services = {
    postgres = {
      host     = local.postgres_vip
      port     = local.postgres_rw_port
      password = random_password.gitlab_db_password.result
      username = "gitlab"
      database = "gitlabhq_production"

      ssl = {
        mode = "verify-ca"
      }

      ssl_secret = kubernetes_secret.gitlab_postgres_tls.metadata[0].name
    }
    redis = {
      host     = local.redis_vip
      port     = local.redis_port
      password = local.redis_password
      scheme   = "rediss"
    }
    minio = {
      ip         = local.minio_vip
      hostname   = local.minio_hostname
      endpoint   = local.minio_address
      access_key = ""
      secret_key = ""
      region     = local.s3_region
      buckets = {
        for func_key, bucket_name in local.minio_function_map : func_key => {
          name       = bucket_name
          access_key = data.vault_generic_secret.s3_credentials[func_key].data["access_key"]
          secret_key = data.vault_generic_secret.s3_credentials[func_key].data["secret_key"]
        }
      }
    }
  }

  # Internal Secrets of Rails, Gitaly, etc.
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
