
# To Resolve CipherError during Greenfield GitLab Migration
resource "kubernetes_job" "gitlab_db_token_reset" {
  count = var.enable_db_token_reset ? 1 : 0

  metadata {
    name      = "gitlab-db-token-reset"
    namespace = kubernetes_namespace.gitlab_ns.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "gitlab-db-token-reset"
        }
      }
      spec {
        container {
          name  = "postgres-reset-client"
          image = "${local.gitlab_image_registry}/${local.gitlab_image_repository}/gitlab-toolbox-ce:v18.8.2"

          command = [
            "sh",
            "-c",
            <<-EOT
            # Copy certificates to /tmp/ssl to set strict permission (chmod 0600)
            mkdir -p /tmp/ssl
            cp /etc/ssl/postgres/ca.crt /tmp/ssl/ca.crt
            cp /etc/ssl/postgres/tls.crt /tmp/ssl/tls.crt
            cp /etc/ssl/postgres/tls.key /tmp/ssl/tls.key
            chmod 0600 /tmp/ssl/tls.key

            # Execute psql with mTLS verification enabled
            PGPASSWORD=$PG_PASSWORD \
            PGSSLMODE=verify-ca \
            PGSSLROOTCERT=/tmp/ssl/ca.crt \
            PGSSLCERT=/tmp/ssl/tls.crt \
            PGSSLKEY=/tmp/ssl/tls.key \
            psql -h $DB_HOST -U $DB_USER -d $DB_NAME -p $DB_PORT -c "
              TRUNCATE TABLE application_settings CASCADE;
            "
            EOT
          ]

          env {
            name  = "DB_HOST"
            value = local.fqdn_postgres
          }
          env {
            name  = "DB_PORT"
            value = tostring(local.gitlab_db.port)
          }
          env {
            name  = "DB_USER"
            value = local.gitlab_db.username
          }
          env {
            name  = "DB_NAME"
            value = local.gitlab_db.database
          }
          env {
            name  = "PG_PASSWORD"
            value = local.gitlab_db.password
          }

          volume_mount {
            name       = "postgres-tls"
            mount_path = "/etc/ssl/postgres"
            read_only  = true
          }
        }

        volume {
          name = "postgres-tls"
          secret {
            secret_name = "gitlab-postgres-tls"
          }
        }

        restart_policy = "Never"
      }
    }
    backoff_limit = 2
  }
}
