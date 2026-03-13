
module "harbor_core" {
  source = "../../modules/kubernetes-addons/helm-chart-harbor"

  ca_bundle = local.ca_bundle_config

  helm_config = {
    version   = var.harbor_helm_config.version
    namespace = var.harbor_helm_config.namespace
    timeout   = 600
  }

  certificate_config = var.certificate_config

  harbor_config = {
    hostname       = local.harbor_hostname
    admin_password = local.harbor_admin_password
    notary_prefix  = var.harbor_helm_config.notary_prefix
    secret_key     = random_password.harbor_core_secret_key.result
  }

  ingress_config = {
    class_name      = var.harbor_helm_config.ingress_class
    tls_secret_name = var.harbor_helm_config.tls_secret_name
    issuer_name     = local.issuer_name
    issuer_kind     = local.issuer_kind
  }

  external_services = {
    postgres = {
      host     = local.postgres_address
      password = local.harbor_pg_password
      port     = local.postgres_rw_port
    }
    redis = {
      host     = local.redis_address
      password = local.redis_password
    }
    s3 = {
      bucket     = var.object_storage_config.bucket_name
      region     = var.object_storage_config.region
      access_key = local.minio_access_key
      secret_key = local.minio_secret_key
      endpoint   = local.minio_address
    }
  }
}

module "harbor_system_config" {
  source     = "../../modules/configuration/harbor-system-config"
  depends_on = [module.harbor_core] # Should be after Harbor Helm Chart Pod Ready
}
