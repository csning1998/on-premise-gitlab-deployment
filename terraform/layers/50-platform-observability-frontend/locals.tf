
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
    metadata             = data.terraform_remote_state.metadata.outputs
    vault_pki            = data.terraform_remote_state.vault_pki.outputs
    minio                = data.terraform_remote_state.minio.outputs
    minio_provision      = data.terraform_remote_state.minio_provision.outputs
    microk8s_provision   = data.terraform_remote_state.microk8s_provision.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
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
}

# Addons & Trust Engine Context
locals {
  # Network Context
  pod_network_mtu = local.state.metadata.global_network_baseline.global_mtu

  # FQDNs
  grafana_fqdn = local.state.metadata.global_pki_map["observability-frontend"].dns_san[0]
  vault_fqdn   = local.state.metadata.global_pki_map["vault-frontend"].dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry     = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  # Helm Charts Project Sourced from Bootstrapper
  helm_chart_project = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  # K8s API Endpoint for Vault Callback
  api_port     = local.state.metadata.global_topology_network["observability"]["frontend"].ports["api-server"].frontend_port
  api_endpoint = "https://${local.observability_vip}:${local.api_port}"

  # Cluster CA from ConfigMap (SSoT for K8s API verification)
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection
  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  # Map to the specific component identity in Vault PKI (SSoT Driven)
  vault_role_name   = local.state.metadata.global_pki_map["observability-frontend"].role_name
  vault_auth_path   = local.state.metadata.global_pki_map["observability-frontend"].auth_config.path
  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# Vault KV Secrets
locals {
  grafana_admin_password = data.vault_kv_secret_v2.grafana_vars.data["grafana_admin_password"]

  # Loki uses root credentials (per-bucket IAM requires cross-bucket user; tracked in follow-up issue)
  minio_access_key = data.vault_kv_secret_v2.minio_vars.data["minio_root_user"]
  minio_secret_key = data.vault_kv_secret_v2.minio_vars.data["minio_root_password"]

  # Mimir per-bucket credentials (provisioned by 40-provision-observability-minio)
  mimir_blocks_access_key       = data.vault_kv_secret_v2.mimir_blocks_creds.data["access_key"]
  mimir_blocks_secret_key       = data.vault_kv_secret_v2.mimir_blocks_creds.data["secret_key"]
  mimir_ruler_access_key        = data.vault_kv_secret_v2.mimir_ruler_creds.data["access_key"]
  mimir_ruler_secret_key        = data.vault_kv_secret_v2.mimir_ruler_creds.data["secret_key"]
  mimir_alertmanager_access_key = data.vault_kv_secret_v2.mimir_alertmanager_creds.data["access_key"]
  mimir_alertmanager_secret_key = data.vault_kv_secret_v2.mimir_alertmanager_creds.data["secret_key"]
}

# CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "observability-ca-bundle"
    secret_name = "observability-ca-bundle"
    content     = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

# DNS Configuration
locals {
  observability_vip = local.state.microk8s_provision.observability_microk8s_virtual_ip
  vault_vip         = local.state.vault_pki.vault_service_vip
  minio_vip         = local.state.minio.service_vip

  minio_fqdn = local.state.metadata.global_pki_map["observability-minio"].dns_san[0]
  minio_port = local.state.minio.minio_api_port

  dns_hosts = {
    "${local.observability_vip}"                     = join(" ", local.state.metadata.global_pki_map["observability-frontend"].dns_san)
    "${local.vault_vip}"                             = local.vault_fqdn
    "${local.minio_vip}"                             = local.minio_fqdn
    "${local.state.harbor_bootstrapper.service_vip}" = local.harbor_registry
  }
}

# Addons Configuration (Reloader)
locals {
  reloader_oci_config = {
    repository = "oci://${local.harbor_registry}/${local.helm_chart_project}"
  }
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths = data.terraform_remote_state.metadata.outputs.global_credential_paths
}
