
resource "kubernetes_secret" "pat_job_vault_ca" {
  count = var.enable_gitlab_pat_automation ? 1 : 0

  metadata {
    name      = "gitlab-pat-job-vault-ca"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  data = {
    "ca.crt" = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

resource "kubernetes_config_map" "pat_job_gitlab_config" {
  count = var.enable_gitlab_pat_automation ? 1 : 0

  metadata {
    name      = "gitlab-pat-job-gitlab-cfg"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  data = {
    "gitlab.yml" = yamlencode({
      production = {
        gitlab = {
          host  = local.gitlab_frontend_fqdn
          https = true
          port  = 443
        }
        gitaly = {
          token = local.has_praefect ? data.vault_kv_secret_v2.gitaly_secrets.data["praefect_external_token"] : data.vault_kv_secret_v2.gitaly_secrets.data["gitaly_token"]
        }
        repositories = {
          storages = {
            default = {
              path           = "/var/opt/gitlab/repo"
              gitaly_address = "tcp://${local.gitaly_endpoint}"
            }
          }
        }
        incoming_email = { enabled = false }
        extra          = {}
      }
    })
  }
}

resource "kubernetes_secret" "pat_job_db_config" {
  count = var.enable_gitlab_pat_automation ? 1 : 0

  metadata {
    name      = "gitlab-pat-job-db-cfg"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  data = {
    "database.yml" = yamlencode({
      production = {
        main = {
          adapter     = "postgresql"
          encoding    = "unicode"
          host        = local.postgres_fqdn
          port        = local.gitlab_db.port
          username    = local.gitlab_db.username
          database    = local.gitlab_db.database
          password    = local.gitlab_db.password
          sslmode     = "verify-ca"
          sslrootcert = "/tmp/ssl/ca.crt"
          sslcert     = "/tmp/ssl/tls.crt"
          sslkey      = "/tmp/ssl/tls.key"
        }
      }
    })
  }
}

# Generates or renews the GitLab root PAT used to authenticate 60-provision-gitlab-platform's
# provider, replacing the manual bootstrap documented in that layer's README. A new value for
# gitlab_pat_automation_version forces job recreation for a re-run; the script itself, in
# templates/gitlab-pat-automation.sh.tftpl, is idempotent against a still-valid token.
resource "kubernetes_job" "gitlab_pat_automation" {
  count = var.enable_gitlab_pat_automation ? 1 : 0

  depends_on = [
    module.gitlab_core,
    kubernetes_secret.pat_job_vault_ca,
    kubernetes_config_map.pat_job_gitlab_config,
    kubernetes_secret.pat_job_db_config,
  ]

  metadata {
    name      = "gitlab-pat-automation-${var.gitlab_pat_automation_version}"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  spec {
    backoff_limit = 2

    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "pat-automation"
          image = "${local.gitlab_image_registry}/${local.gitlab_image_repository}/gitlab-toolbox-ce:${var.gitlab_version}"

          command = [
            "sh", "-c",
            <<-EOT
              set -e
              mkdir -p /tmp/ssl
              cp /etc/ssl/postgres/ca.crt  /tmp/ssl/ca.crt
              cp /etc/ssl/postgres/tls.crt /tmp/ssl/tls.crt
              cp /etc/ssl/postgres/tls.key /tmp/ssl/tls.key
              chmod 0600 /tmp/ssl/tls.key
              cp /etc/ssl/vault-src/ca.crt /tmp/ssl/vault-ca.crt
              sh /opt/gitlab-pat-automation.sh
            EOT
          ]

          volume_mount {
            name       = "postgres-tls"
            mount_path = "/etc/ssl/postgres"
            read_only  = true
          }

          volume_mount {
            name       = "vault-ca"
            mount_path = "/etc/ssl/vault-src"
            read_only  = true
          }

          volume_mount {
            name       = "db-config"
            mount_path = "/srv/gitlab/config/database.yml"
            sub_path   = "database.yml"
            read_only  = true
          }

          volume_mount {
            name       = "gitlab-config"
            mount_path = "/srv/gitlab/config/gitlab.yml"
            sub_path   = "gitlab.yml"
            read_only  = true
          }

          volume_mount {
            name       = "rails-secrets"
            mount_path = "/srv/gitlab/config/secrets.yml"
            sub_path   = "secrets.yml"
            read_only  = true
          }

          volume_mount {
            name       = "pat-script"
            mount_path = "/opt/gitlab-pat-automation.sh"
            sub_path   = "gitlab-pat-automation.sh"
            read_only  = true
          }
        }

        volume {
          name = "rails-secrets" # matches ESO target.name in resources-gitlab-rails-secrets.tf
          secret { secret_name = local.gitlab_config.rails_secret_name }
        }

        volume {
          name = "postgres-tls"
          secret { secret_name = local.postgres_ca }
        }

        volume {
          name = "vault-ca"
          secret { secret_name = kubernetes_secret.pat_job_vault_ca[0].metadata[0].name }
        }

        volume {
          name = "db-config"
          secret { secret_name = kubernetes_secret.pat_job_db_config[0].metadata[0].name }
        }

        volume {
          name = "gitlab-config"
          config_map { name = kubernetes_config_map.pat_job_gitlab_config[0].metadata[0].name }
        }

        volume {
          name = "pat-script"
          config_map {
            name = kubernetes_config_map.pat_job_script[0].metadata[0].name
            items {
              key  = "gitlab-pat-automation.sh"
              path = "gitlab-pat-automation.sh"
              mode = "0555"
            }
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "10m"
  }
}

resource "kubernetes_config_map" "pat_job_script" {
  count = var.enable_gitlab_pat_automation ? 1 : 0

  metadata {
    name      = "gitlab-pat-job-script"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  data = {
    "gitlab-pat-automation.sh" = templatefile("${path.module}/templates/gitlab-pat-automation.sh.tftpl", {
      vault_addr          = local.vault_endpoint
      vault_kv_path       = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/gitlab/app/pat"
      vault_k8s_auth_path = "kubernetes/gitlab/frontend"
      vault_k8s_role      = "core-gitlab-frontend-role"
      gitlab_internal_url = "http://gitlab-webservice-default.${kubernetes_namespace.gitlab_ns.metadata[0].name}.svc.cluster.local:8080"
      pat_ttl_days        = var.gitlab_pat_ttl_days
      pat_scopes          = join(",", sort(["api", "admin_mode", "read_user"]))
    })
  }
}
