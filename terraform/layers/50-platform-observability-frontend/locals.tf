
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
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision            = data.terraform_remote_state.provision.outputs
    gitlab_frontend      = data.terraform_remote_state.gitlab_frontend.outputs
    harbor_frontend      = data.terraform_remote_state.harbor_frontend.outputs
  }
}

# Trust Engine Context (sourced from provision layer state, aligned with GitLab pattern)
locals {
  issuer_name = local.state.provision.trust_context.issuer_name
  issuer_kind = local.state.provision.trust_context.issuer_kind
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
  grafana_fqdn = local.state.metadata.global_pki_map["observability-frontend"].dns_san[0]

  harbor_registry     = local.state.metadata.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name

  helm_chart_project = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  vault_api_port = local.state.metadata.global_topology_network["vault"]["frontend"].ports["api"].frontend_port
  vault_address  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"

  vault_role_name = local.state.metadata.global_pki_map["observability-frontend"].role_name
  vault_auth_path = local.state.metadata.global_pki_map["observability-frontend"].auth_config.path
}

# Observability VM Scrape Targets
locals {
  port_haproxy_stats                  = local.state.metadata.global_topology_network["central-lb"]["frontend"].ports["stats"].frontend_port
  central_lb_ips                      = local.state.metadata.global_topology_network["central-lb"]["frontend"].node_ips
  vault_metrics_address               = "${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  keycloak_metrics_address            = "${local.state.metadata.global_topology_network["keycloak"]["frontend"].node_ips[0]}:${local.state.metadata.global_topology_network["keycloak"]["frontend"].ports["mgmt"].frontend_port}"
  harbor_bootstrapper_metrics_address = "${local.state.metadata.global_topology_network["harbor-bootstrapper"]["frontend"].node_ips[0]}:${local.state.metadata.global_topology_network["harbor-bootstrapper"]["frontend"].ports["metrics"].frontend_port}"
  mimir_tenants_extra = [
    local.state.gitlab_frontend.mimir_tenant_id,
    local.state.harbor_frontend.mimir_tenant_id,
  ]
}

# CA Bundle Configuration
locals {
  ca_bundle_config = {
    name        = "observability-ca-bundle"
    secret_name = "observability-ca-bundle"
    content     = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
}

# MinIO Connection
locals {
  minio_fqdn = local.state.metadata.global_pki_map["observability-minio"].dns_san[0]
  minio_port = local.state.minio.minio_api_port
}

# Mimir External FQDN (derived from PKI map; startswith guards against base SANs)
locals {
  mimir_fqdn = [
    for san in local.state.metadata.global_pki_map["observability-frontend"].dns_san :
    san if startswith(san, "mimir.")
  ][0]
}

# Credential path map alias derived from foundation metadata (L00 SSoT)
locals {
  credential_paths      = data.terraform_remote_state.metadata.outputs.global_credential_paths
  s3_credentials_prefix = "${local.state.metadata.vault_kv_namespace}/observability/app/s3_credentials"
}
