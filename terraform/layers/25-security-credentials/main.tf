
# GitLab core component credentials

module "gitlab_postgres" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "postgres"

  generate = {
    pg_superuser_password   = { length = 32 }
    pg_replication_password = { length = 32 }
    pg_vrrp_secret          = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "gitlab_redis" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "redis"

  generate = {
    redis_masterauth  = { length = 32 }
    redis_requirepass = { length = 32 }
    redis_vrrp_secret = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "gitlab_minio" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "minio"

  static = {
    minio_root_user = var.minio_root_user
  }

  generate = {
    minio_root_password = { length = 32 }
    minio_vrrp_secret   = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

# Harbor core component credentials

module "harbor_postgres" {
  source = "../../modules/configuration/vault-credential"

  domain    = "harbor"
  component = "postgres"

  generate = {
    pg_superuser_password   = { length = 32 }
    pg_replication_password = { length = 32 }
    pg_vrrp_secret          = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "harbor_redis" {
  source = "../../modules/configuration/vault-credential"

  domain    = "harbor"
  component = "redis"

  generate = {
    redis_masterauth  = { length = 32 }
    redis_requirepass = { length = 32 }
    redis_vrrp_secret = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "harbor_minio" {
  source = "../../modules/configuration/vault-credential"

  domain    = "harbor"
  component = "minio"

  static = {
    minio_root_user = var.minio_root_user
  }

  generate = {
    minio_root_password = { length = 32 }
    minio_vrrp_secret   = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

# Keycloak credentials

module "keycloak_server" {
  source = "../../modules/configuration/vault-credential"

  domain    = "keycloak"
  component = "frontend"

  static = {
    keycloak_admin_user = var.keycloak_admin_user
    keycloak_db_user    = var.keycloak_db_user
  }

  generate = {
    keycloak_admin_password = { length = 32 }
    keycloak_db_password    = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

# Harbor bootstrapper credentials

module "harbor_bootstrapper" {
  source = "../../modules/configuration/vault-credential"

  domain    = "harbor-bootstrapper"
  component = "frontend"

  generate = {
    harbor_bootstrapper_admin_password = { length = 32 }
    harbor_bootstrapper_pg_db_password = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

# GitLab Gitaly/Praefect application credentials

module "gitlab_app_gitaly" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "gitaly"

  generate = merge(
    {
      gitaly_token        = { length = 32 }
      gitlab_shell_secret = { length = 32 }
    },
    var.gitlab_enable_praefect ? {
      praefect_external_token = { length = 32 }
      praefect_db_password    = { length = 32 }
    } : {}
  )

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "gitlab_app_postgres" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "praefect-patroni"

  generate = {
    pg_replication_password = { length = 32 }
    pg_superuser_password   = { length = 32 }
    pg_vrrp_secret          = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "gitlab_app_internal" {
  source = "../../modules/configuration/vault-credential"

  domain    = "gitlab"
  component = "frontend"

  generate = {
    rails_secret_key = { length = 32 }
    root_password    = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}

module "harbor_app_internal" {
  source = "../../modules/configuration/vault-credential"

  domain    = "harbor"
  component = "frontend"

  generate = {
    harbor_admin_password = { length = 32 }
  }

  vault_kv_namespace = local.vault_kv_namespace

  providers = {
    vault.production = vault.production
  }
}
