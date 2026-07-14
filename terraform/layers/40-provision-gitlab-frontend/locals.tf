
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

# 1. External State Context
locals {
  state = {
    vault_frontend       = data.terraform_remote_state.vault_frontend.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    redis                = data.terraform_remote_state.redis.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    minio                = data.terraform_remote_state.minio.outputs
    kubeadm              = data.terraform_remote_state.kubeadm.outputs
    gitaly_praefect      = data.terraform_remote_state.gitaly_praefect.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision_databases  = data.terraform_remote_state.provision_databases.outputs
  }
}

# 2. K8s Provider Authentication Context
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

  # Trust Engine Contract (Internal to Layer 50)
  issuer_name = module.platform_trust_engine.issuer_name
  issuer_kind = module.platform_trust_engine.issuer_kind
}

# 3. Addons & Trust Engine Context
locals {
  # Network Context
  pod_network_mtu = local.state.kubeadm.global_network_mtu

  # FQDNs
  gitlab_frontend_fqdn     = local.state.vault_pki.global_pki_map["gitlab-frontend"].dns_san[0]
  vault_fqdn               = local.state.vault_pki.global_pki_map["vault-frontend"].dns_san[0]
  harbor_bootstrapper_fqdn = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  minio_fqdn               = local.state.vault_pki.global_pki_map["gitlab-minio"].dns_san[0]
  postgres_fqdn            = local.state.vault_pki.global_pki_map["gitlab-postgres"].dns_san[0]
  redis_fqdn               = local.state.vault_pki.global_pki_map["gitlab-redis"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.harbor_bootstrapper_fqdn
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  harbor_gitlab_proxy = local.state.harbor_bootstrapper.proxy_caches.gitlab_com.project_name
  harbor_ghcr_proxy   = local.state.harbor_bootstrapper.proxy_caches.ghcr_io.project_name
  harbor_gcr_proxy    = local.state.harbor_bootstrapper.proxy_caches.gcr_io.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  # GitLab CNG image registry and repository routed through Harbor Bootstrapper proxy
  gitlab_image_registry   = local.harbor_registry
  gitlab_image_repository = "${local.harbor_gitlab_proxy}/gitlab-org/build/cng"

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.state.kubeadm.k8s_api_port
  api_endpoint = "https://${local.state.kubeadm.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca  = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
  postgres_ca = "gitlab-postgres-tls"

  # Vault Connection (Standardized)
  vault_api_port          = local.state.vault_frontend.vault_api_port
  vault_endpoint          = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert           = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path          = local.state.vault_pki.pki_configuration.path
  vault_pki_lease_default = local.state.vault_pki.pki_configuration.lease_durations.default
  vault_pki_lease_agent   = local.state.vault_pki.pki_configuration.lease_durations.agent

  # Map to the specific component identity in Vault PKI (SSoT Driven)
  vault_role_name   = local.state.vault_pki.global_pki_map["gitlab-frontend"].role_name
  vault_auth_path   = local.state.vault_pki.global_pki_map["gitlab-frontend"].auth_config.path
  vault_policy_name = "${local.vault_role_name}-pki-policy"

  # Kubelet Serving Certificate Approval Configuration
  node_serving_cert_regex = "^${local.state.kubeadm.cluster_name}-.*$"
}

# 4. External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  postgres_rw_port = local.state.postgres.connection_info.port
  redis_port       = local.state.redis.connection_info.port
  minio_port       = local.state.minio.connection_info.port

  # VIPs from LB Infrastructure
  postgres_vip  = local.state.postgres.connection_info.host
  redis_vip     = local.state.redis.connection_info.host
  minio_vip     = local.state.minio.connection_info.host
  minio_address = "https://${local.minio_fqdn}:${local.minio_port}"

  # GitLab Application Database Context
  # Directly sourcing from Vault to avoid state output dependencies
  gitlab_db = {
    username = data.vault_kv_secret_v2.gitlab_app_database.data["username"]
    password = data.vault_kv_secret_v2.gitlab_app_database.data["password"]
    database = data.vault_kv_secret_v2.gitlab_app_database.data["database"]
    host     = data.vault_kv_secret_v2.gitlab_app_database.data["host"]
    port     = tonumber(data.vault_kv_secret_v2.gitlab_app_database.data["port"])
  }

  redis_password = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]

  # Gitaly / Praefect storage backend context
  _has_praefect  = length([for name, node in local.state.gitaly_praefect.topology_cluster : name if length(regexall("praefect", name)) > 0]) > 0
  _praefect_vip  = local.state.gitaly_praefect.praefect_connection_info.host
  _praefect_port = local.state.gitaly_praefect.praefect_connection_info.port
  _gitaly_vip    = local.state.gitaly_praefect.gitaly_connection_info.host
  _gitaly_port   = local.state.gitaly_praefect.gitaly_connection_info.port
}

# 5. DNS Configuration (Standardized)
locals {
  dns_hosts = merge(
    {
      "${local.state.kubeadm.service_vip}"         = local.gitlab_frontend_fqdn
      "${local.state.vault_pki.vault_service_vip}" = local.vault_fqdn

      # Dependency Roles
      "${local.state.redis.service_vip}"    = local.redis_fqdn
      "${local.state.postgres.service_vip}" = local.postgres_fqdn
      "${local.state.minio.service_vip}"    = local.minio_fqdn

      # Container Registry. This entry is required for pod image pulls because dnsmasq at 172.16.2.1 does not
      # resolve the domain name, necessitating static hosts entry resolution by CoreDNS.
      "${local.state.harbor_bootstrapper.service_vip}" = local.harbor_bootstrapper_fqdn
    },
    # Dynamic Node Resolution (Required for Kubelet CSR Approver DNS checks)
    merge([
      for node_name, node in local.state.kubeadm.topology_cluster : {
        "${node.ip}" = "${node_name} ${node_name}.cluster.local"
      }
    ]...)
  )
}

# 6. CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name

    # Use the current active CA bundle from Vault PKI directly
    content = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

# 7. Object Storage Mappings
locals {
  s3_region          = "us-east-1"
  minio_function_map = local.state.provision_databases.minio_function_map
}

# 8. Addons Configuration (Reloader)
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

# Credential path map alias passed through from L25 security-pki
locals {
  credential_paths = data.terraform_remote_state.vault_pki.outputs.global_credential_paths
}
