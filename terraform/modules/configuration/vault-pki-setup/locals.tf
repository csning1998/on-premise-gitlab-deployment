
locals {
  root_domain = var.root_domain

  platforms = toset(["gitlab", "harbor"])

  dev_harbor_ingress_domains = [
    "dev-harbor.${local.root_domain}",
    "notary.dev-harbor.${local.root_domain}",
  ]

  harbor_ingress_domains = [
    "harbor.${local.root_domain}",
    "notary.harbor.${local.root_domain}",
  ]

  gitlab_ingress_domains = [
    "gitlab.${local.root_domain}",
    "kas.gitlab.${local.root_domain}",
    "registry.gitlab.${local.root_domain}",
    "minio.gitlab.${local.root_domain}"
  ]

  ingress_services = {
    "gitlab" = {
      domains = local.gitlab_ingress_domains
    }
    "harbor" = {
      domains = local.harbor_ingress_domains
    }
  }
}

locals {
  # 1. Define the difference configuration for database-like services
  # key: database service name
  # value: unique subdomain prefix for the service (excluding platform name)
  db_service_config = {
    postgres = ["pg"]
    redis    = ["redis"]
    minio    = ["s3", "console"]
  }

  # 2. Flatten. for instance:
  # {
  #   "gitlab-postgres" = { platform = "gitlab", service = "postgres", prefixes = ["pg"] }
  #   "harbor-redis"    = { platform = "harbor", service = "redis",    prefixes = ["redis"] }
  #   ...
  # }
  db_roles_flat = merge([
    for service, prefixes in local.db_service_config : {
      for platform in local.platforms : "${platform}-${service}" => {
        platform = platform
        service  = service
        prefixes = prefixes
      }
    }
  ]...)
}
