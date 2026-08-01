
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# External State Context
locals {
  state = {
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    credentials          = data.terraform_remote_state.credentials.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    provision            = data.terraform_remote_state.provision.outputs
    provision_databases  = data.terraform_remote_state.provision_databases.outputs
  }
}

# K8s Provider Authentication Context
locals {
  kubeconfig   = yamldecode(base64decode(ephemeral.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  issuer_name = local.state.provision.issuer_name
  issuer_kind = local.state.provision.issuer_kind
}

# Application Context
locals {
  harbor_frontend_fqdn = local.state.vault_pki.global_pki_map["harbor-frontend"].dns_san[0]

  harbor_registry     = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  vault_api_port = local.state.provision.network_context.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  pg_port = local.state.provision_databases.postgres_connection_info.port
}

# Vault KV Secrets
locals {
  harbor_db = {
    username = data.vault_kv_secret_v2.harbor_app_database.data["username"]
    password = data.vault_kv_secret_v2.harbor_app_database.data["password"]
    database = data.vault_kv_secret_v2.harbor_app_database.data["database"]
    host     = data.vault_kv_secret_v2.harbor_app_database.data["host"]
    port     = tonumber(data.vault_kv_secret_v2.harbor_app_database.data["port"])
  }

  harbor_admin_password = data.vault_kv_secret_v2.harbor_vars.data["harbor_admin_password"]

  redis_password   = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]
  minio_access_key = data.vault_kv_secret_v2.s3_vars.data["access_key"]
  minio_secret_key = data.vault_kv_secret_v2.s3_vars.data["secret_key"]
}

# CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "harbor-ca-bundle"
    secret_name = "harbor-ca-bundle"
    content     = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

# FQDNs and Service Endpoints
locals {
  redis_fqdn             = local.state.vault_pki.global_pki_map["harbor-redis"].dns_san[0]
  postgres_fqdn          = local.state.vault_pki.global_pki_map["harbor-postgres"].dns_san[0]
  minio_fqdn             = local.state.vault_pki.global_pki_map["harbor-minio"].dns_san[0]
  minio_port             = local.state.provision_databases.minio_connection_info.port
  mimir_fqdn             = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]
  mimir_remote_write_url = "https://${local.mimir_fqdn}/api/v1/push"
  loki_fqdn              = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "loki.")][0]
  loki_push_url          = "https://${local.loki_fqdn}/loki/api/v1/push"
}

# Addons Configuration (Reloader annotations)
locals {
  _harbor_component_common = {
    podAnnotations = {
      "secret.reloader.stakater.com/reload" = local.ca_bundle_config.name
    }
  }

  harbor_helm_overrides = {
    core       = local._harbor_component_common
    jobservice = local._harbor_component_common
    registry   = local._harbor_component_common
    trivy      = local._harbor_component_common
  }
}

locals {
  credential_paths = local.state.credentials.global_credential_paths
}

# Observability Endpoint Context
locals {
  mimir_tenant_id        = "harbor"
  postgres_exporter_port = local.state.provision_databases.observability_targets.postgres_exporter_port
  redis_exporter_port    = local.state.provision_databases.observability_targets.redis_exporter_port
  etcd_client_port       = local.state.provision_databases.observability_targets.etcd_client_port

  postgres_vip = local.state.provision_databases.postgres_connection_info.host
  redis_vip    = local.state.provision_databases.redis_connection_info.host
  minio_vip    = local.state.provision_databases.minio_connection_info.host
  etcd_ips     = local.state.provision_databases.observability_targets.etcd_ips
}

# Node Exporter Context
locals {
  node_exporter_port = local.state.provision.node_exporter_targets.port
  node_exporter_ip_groups = {
    postgres = local.state.provision_databases.observability_targets.postgres_ips
    redis    = local.state.provision_databases.observability_targets.redis_ips
    minio    = local.state.provision_databases.observability_targets.minio_ips
    etcd     = local.etcd_ips
    microk8s = local.state.provision.node_exporter_targets.ips
  }
}

# External upstream blackbox probe targets derived from the Harbor proxy-cache upstreams.
# These are probed from the Harbor tenant Alloy instance using the system trust store,
# rendering Docker Hub rate limits and upstream outages visible prior to affecting CI workloads.
locals {
  blackbox_external_targets = [
    for key, cache in local.state.harbor_bootstrapper.proxy_caches : {
      name    = cache.registry_name
      address = cache.endpoint_url
      module  = "http_2xx_public"
    }
  ]
}
