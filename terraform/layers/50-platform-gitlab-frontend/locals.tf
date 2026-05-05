
# 1. External State Context
locals {
  state = {
    metadata             = data.terraform_remote_state.metadata.outputs
    network              = data.terraform_remote_state.network.outputs.infrastructure_map
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    redis                = data.terraform_remote_state.redis.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    minio                = data.terraform_remote_state.minio.outputs
    kubeadm              = data.terraform_remote_state.kubeadm.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision_databases  = data.terraform_remote_state.provision_databases.outputs
    provision            = data.terraform_remote_state.provision.outputs
  }
}

# 2. K8s Provider Authentication Context
locals {
  kubeconfig   = yamldecode(base64decode(data.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  # Trust Engine Contract (Sourced from Provisioning Layer 40)
  issuer_name = local.state.provision.issuer_name
  issuer_kind = local.state.provision.issuer_kind
}

# 3. Application Endpoint Context
locals {
  # FQDNs
  fqdn_gitlab              = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_minio               = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.fqdn_harbor_bootstrapper
  harbor_gitlab_proxy = local.state.harbor_bootstrapper.proxy_caches.gitlab_com.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  # GitLab CNG image registry and repository routed through Harbor Bootstrapper proxy
  gitlab_image_registry   = local.harbor_registry
  gitlab_image_repository = "${local.harbor_gitlab_proxy}/gitlab-org/build/cng"

  # Cluster CA from ConfigMap
  cluster_ca  = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
  postgres_ca = "gitlab-postgres-tls"

  # Vault Connection (Standardized)
  vault_address           = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_api_port          = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_pki_path          = local.state.vault_pki.pki_configuration.path
  vault_pki_lease_default = local.state.vault_pki.pki_configuration.lease_durations.default
  vault_pki_lease_agent   = local.state.vault_pki.pki_configuration.lease_durations.agent
}

# 4. External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  redis_port = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
  minio_port = local.state.network["core-gitlab-minio"].lb_config.ports["api"].frontend_port

  # VIPs from LB Infrastructure
  redis_vip     = local.state.network["core-gitlab-redis"].lb_config.vip
  minio_vip     = local.state.network["core-gitlab-minio"].lb_config.vip
  minio_address = "https://${local.fqdn_minio}:${local.minio_port}"

  # GitLab Application Database Context
  gitlab_db = {
    username = local.state.provision_databases.postgres_connection_info.username
    password = data.vault_kv_secret_v2.app_vars.data["gitlab_pg_db_password"]
    database = local.state.provision_databases.postgres_connection_info.database
    host     = local.state.provision_databases.postgres_connection_info.host
    port     = local.state.provision_databases.postgres_connection_info.port
  }

  # Infrastructure Credentials discovered from vault
  redis_password = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]
}

# 5. CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name

    # Use the aggregated trust bundle from Vault PKI (Root CA + Issuing CA)
    content = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

# 6. Object Storage Mappings
locals {
  s3_region          = "us-east-1"
  minio_function_map = local.state.provision_databases.minio_function_map
}

# 7. Reloader Configuration (Platform Level)
locals {
  reloader_oci_config = {
    repository = "oci://${local.harbor_registry}/${local.helm_chart_project}"
  }

  # Internal helper for reloader annotations to avoid duplication across components
  _gitlab_reloader_common = {
    deployment = {
      annotations = {
        "reloader.stakater.com/auto"          = "true"
        "secret.reloader.stakater.com/reload" = local.postgres_ca
      }
    }
  }

  gitlab_reloader_annotations = {
    gitlab = {
      webservice = local._gitlab_reloader_common
      sidekiq    = local._gitlab_reloader_common
    }
  }
}
