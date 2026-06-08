
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
  pod_network_mtu = local.state.metadata.global_network_baseline.global_mtu

  # FQDNs
  fqdn_gitlab              = local.state.metadata.global_pki_map["gitlab-frontend"].dns_san[0]
  fqdn_vault               = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]
  fqdn_harbor_bootstrapper = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  fqdn_minio               = local.state.metadata.global_pki_map["gitlab-minio"].dns_san[0]
  fqdn_postgres            = local.state.metadata.global_pki_map["gitlab-postgres"].dns_san[0]
  fqdn_redis               = local.state.metadata.global_pki_map["gitlab-redis"].dns_san[0]

  # Compatibility Aliases
  gitlab_fqdn = local.fqdn_gitlab
  vault_fqdn  = local.fqdn_vault

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.fqdn_harbor_bootstrapper
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
  api_port     = local.state.metadata.global_topology_network["gitlab"]["frontend"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.state.kubeadm.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca  = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]
  postgres_ca = "gitlab-postgres-tls"

  # Vault Connection (Standardized)
  vault_api_port          = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address           = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert           = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path          = local.state.vault_pki.pki_configuration.path
  vault_pki_lease_default = local.state.vault_pki.pki_configuration.lease_durations.default
  vault_pki_lease_agent   = local.state.vault_pki.pki_configuration.lease_durations.agent

  # Map to the specific component identity in Vault PKI (SSoT Driven)
  vault_role_name   = local.state.metadata.global_pki_map["gitlab-frontend"].role_name
  vault_auth_path   = local.state.metadata.global_pki_map["gitlab-frontend"].auth_config.path
  vault_policy_name = "${local.vault_role_name}-pki-policy"

  # Kubelet Serving Certificate Approval Configuration
  node_serving_cert_regex = "^${local.state.kubeadm.cluster_name}-.*$"
}

# 4. External Service Address & Ports
locals {
  # Dynamic Ports/VIPs from Layer 10 (Shared Load Balancer)
  postgres_rw_port = local.state.network["core-gitlab-postgres"].lb_config.ports["rw-proxy"].frontend_port
  redis_port       = local.state.network["core-gitlab-redis"].lb_config.ports["main"].frontend_port
  minio_port       = local.state.network["core-gitlab-minio"].lb_config.ports["api"].frontend_port

  # VIPs from LB Infrastructure
  postgres_vip  = local.state.network["core-gitlab-postgres"].lb_config.vip
  redis_vip     = local.state.network["core-gitlab-redis"].lb_config.vip
  minio_vip     = local.state.network["core-gitlab-minio"].lb_config.vip
  minio_address = "https://${local.fqdn_minio}:${local.minio_port}"

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
}

# 5. DNS Configuration (Standardized)
locals {
  dns_hosts = merge(
    {
      "${local.state.kubeadm.service_vip}"         = local.fqdn_gitlab
      "${local.state.vault_pki.vault_service_vip}" = local.fqdn_vault

      # Dependency Roles
      "${local.state.redis.service_vip}"    = local.fqdn_redis
      "${local.state.postgres.service_vip}" = local.fqdn_postgres
      "${local.state.minio.service_vip}"    = local.fqdn_minio

      # Container Registry (Required for pod image pulls — dnsmasq at 172.16.2.1 does not
      # resolve domain name; CoreDNS must resolve this via static hosts entry)
      "${local.state.network["core-harbor-bootstrapper-frontend"].lb_config.vip}" = local.fqdn_harbor_bootstrapper
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

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}
