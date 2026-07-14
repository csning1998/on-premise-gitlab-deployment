
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
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    microk8s_provision   = data.terraform_remote_state.microk8s_provision.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    observability_infra  = data.terraform_remote_state.observability_infra.outputs
    redis                = data.terraform_remote_state.redis.outputs
    postgres             = data.terraform_remote_state.postgres.outputs
    minio                = data.terraform_remote_state.minio.outputs
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

  issuer_name = module.platform_trust_engine.issuer_name
  issuer_kind = module.platform_trust_engine.issuer_kind
}

# 3. Addons & Trust Engine Context
locals {
  pod_network_mtu = local.state.microk8s_provision.global_network_mtu

  harbor_frontend_fqdn = local.state.vault_pki.global_pki_map["harbor-frontend"].dns_san[0]
  vault_fqdn           = local.state.vault_pki.global_pki_map["vault-frontend"].dns_san[0]

  harbor_registry     = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_quay_proxy   = local.state.harbor_bootstrapper.proxy_caches.quay_io.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  harbor_ghcr_proxy   = local.state.harbor_bootstrapper.proxy_caches.ghcr_io.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  api_port     = local.state.microk8s_provision.k8s_api_port
  api_endpoint = "https://${local.state.microk8s_provision.harbor_microk8s_virtual_ip}:${local.api_port}"

  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  vault_api_port = local.state.vault_frontend.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert  = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  vault_pki_path = local.state.vault_pki.pki_configuration.path

  vault_role_name = local.state.vault_pki.global_pki_map["harbor-frontend"].role_name
  vault_auth_path = local.state.vault_pki.global_pki_map["harbor-frontend"].auth_config.path
}

# 4. DNS Configuration
locals {
  harbor_frontend_vip = local.state.microk8s_provision.harbor_microk8s_virtual_ip
  vault_vip           = local.state.vault_pki.vault_service_vip
  redis_vip           = local.state.redis.service_vip
  postgres_vip        = local.state.postgres.service_vip
  minio_vip           = local.state.minio.service_vip
  observability_vip   = local.state.observability_infra.observability_microk8s_vip

  redis_fqdn    = local.state.vault_pki.global_pki_map["harbor-redis"].dns_san[0]
  postgres_fqdn = local.state.vault_pki.global_pki_map["harbor-postgres"].dns_san[0]
  minio_fqdn    = local.state.vault_pki.global_pki_map["harbor-minio"].dns_san[0]
  mimir_fqdn    = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]

  dns_hosts = {
    "${local.harbor_frontend_vip}"                   = "${local.harbor_frontend_fqdn} notary.${local.harbor_frontend_fqdn}"
    "${local.vault_vip}"                             = local.vault_fqdn
    "${local.redis_vip}"                             = local.redis_fqdn
    "${local.postgres_vip}"                          = local.postgres_fqdn
    "${local.minio_vip}"                             = local.minio_fqdn
    "${local.state.harbor_bootstrapper.service_vip}" = local.harbor_registry
    "${local.observability_vip}"                     = local.mimir_fqdn
  }
}

# 5. Addons Configuration (Reloader)
locals {
  reloader_oci_config = {
    repository = "oci://${local.harbor_registry}/${local.helm_chart_project}"
  }
}
