
resource "helm_release" "harbor" {

  depends_on = [
    module.harbor_db_init,
    module.ingress_controller,
    module.harbor_tls
  ]

  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = "1.18.0" # Released in 18 Sep, 2025; App version 2.14.0
  namespace  = kubernetes_namespace.harbor.metadata[0].name

  timeout = 600

  values = [
    yamlencode({
      expose = {
        type = "ingress"
        tls = {
          enabled    = true
          secretName = module.harbor_tls.secret_name
        }
        ingress = {
          hosts = {
            core = var.harbor_hostname
          }
          className = "nginx"
        }
      }

      externalURL = "https://${var.harbor_hostname}"

      # External Postgres via HAProxy VIP
      database = {
        type = "external"
        external = {
          host               = data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip
          port               = tostring(data.terraform_remote_state.postgres.outputs.harbor_postgres_haproxy_rw_port)
          username           = "harbor"
          password           = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
          coreDatabase       = "registry"
          jobServiceDatabase = "registry" # Simplified configuration, share DB (Production environment suggest separate)
        }
      }

      # External Redis via HAProxy VIP
      redis = {
        type = "external"
        external = {
          addr                = "${data.terraform_remote_state.redis.outputs.harbor_redis_virtual_ip}:6379"
          password            = data.vault_generic_secret.db_vars.data["redis_requirepass"]
          sentinel_master_set = "" # Leave empty to force single point mode
        }
      }

      # External MinIO via HAProxy VIP
      persistence = {
        enabled = true
        imageChartStorage = {
          type = "s3"
          s3 = {
            region         = "us-east-1"
            bucket         = "harbor-registry"
            accesskey      = data.vault_generic_secret.db_vars.data["minio_root_user"] # MinIO Root User corresponding to Ansible defaults
            secretkey      = data.vault_generic_secret.db_vars.data["minio_root_password"]
            regionendpoint = "http://${data.terraform_remote_state.minio.outputs.harbor_minio_virtual_ip}:9000"
            encrypt        = false
            secure         = false
            v4auth         = true
          }
        }
      }

      harborAdminPassword = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]

      # Disable built-in components
      trivy  = { enabled = true }
      notary = { enabled = false }
    })
  ]
}
