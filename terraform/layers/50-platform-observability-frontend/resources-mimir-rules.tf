
# mimirtool rules-sync for the gitlab tenant. Rule files live under rules/<tenant>/*.yaml, and the
# ConfigMap content hash is embedded in the Job name since Kubernetes Jobs are immutable once created.
# A rule file edit therefore forces a new Job instead of a no-op reapply.
locals {
  mimir_rules_gitlab_files = fileset("${path.module}/rules/gitlab", "*.yaml")
  mimir_rules_gitlab_data  = { for f in local.mimir_rules_gitlab_files : f => file("${path.module}/rules/gitlab/${f}") }
  mimir_rules_gitlab_hash  = substr(sha256(jsonencode(local.mimir_rules_gitlab_data)), 0, 8)
}

resource "kubernetes_config_map" "mimir_rules_gitlab" {
  metadata {
    name      = "mimir-rules-gitlab"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = local.mimir_rules_gitlab_data
}

resource "kubernetes_job" "mimir_rules_sync_gitlab" {
  depends_on = [
    module.mimir,
    kubernetes_config_map.mimir_rules_gitlab,
  ]

  metadata {
    name      = "mimir-rules-sync-gitlab-${local.mimir_rules_gitlab_hash}"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  spec {
    backoff_limit              = 4
    ttl_seconds_after_finished = 3600

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "mimir-rules-sync"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "mimirtool"
          image = "${local.harbor_registry}/${local.harbor_docker_proxy}/grafana/mimirtool:${var.mimirtool_version}"

          command = concat(
            [
              "mimirtool", "rules", "sync",
              "--address=http://mimir-gateway.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8080",
              "--id=gitlab",
            ],
            [for f in local.mimir_rules_gitlab_files : "/rules/${f}"]
          )

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "rules"
            mount_path = "/rules"
            read_only  = true
          }
        }

        volume {
          name = "rules"
          config_map { name = kubernetes_config_map.mimir_rules_gitlab.metadata[0].name }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "10m"
  }
}
