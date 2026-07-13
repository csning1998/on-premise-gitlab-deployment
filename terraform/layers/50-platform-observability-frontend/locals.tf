
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
    minio_provision      = data.terraform_remote_state.minio_provision.outputs
    harbor_bootstrapper  = data.terraform_remote_state.harbor_bootstrapper.outputs
    vault_prod_bootstrap = data.terraform_remote_state.vault_prod_bootstrap.outputs
    provision            = data.terraform_remote_state.provision.outputs
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
  grafana_fqdn = local.state.vault_pki.global_pki_map["observability-frontend"].dns_san[0]

  harbor_registry     = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]
  harbor_docker_proxy = local.state.harbor_bootstrapper.proxy_caches.docker_hub.project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper.proxy_caches.k8s_io.project_name
  helm_chart_project  = local.state.harbor_bootstrapper.proxy_oci.helm_charts.name

  vault_api_port  = local.state.provision.vault_api_port
  vault_endpoint  = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  vault_role_name = local.state.vault_pki.global_pki_map["observability-frontend"].role_name
  vault_auth_path = local.state.vault_pki.global_pki_map["observability-frontend"].auth_config.path
}

# Observability VM Scrape Targets
locals {
  port_haproxy_stats                  = local.state.provision.vm_scrape_targets.haproxy_stats_port
  central_lb_ips                      = local.state.provision.vm_scrape_targets.central_lb_ips
  vault_metrics_address               = "${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
  keycloak_metrics_address            = local.state.provision.vm_scrape_targets.keycloak_metrics_address
  keycloak_node_ip                    = local.state.provision.vm_scrape_targets.keycloak_node_ip
  harbor_bootstrapper_metrics_address = local.state.provision.vm_scrape_targets.harbor_bootstrapper_metrics_address
}

# Node Exporter Context
locals {
  node_exporter_port = local.state.provision.node_exporter_targets.port
  node_exporter_ip_groups = {
    microk8s            = local.state.provision.node_exporter_targets.ips
    central-lb          = local.central_lb_ips
    keycloak            = [local.keycloak_node_ip]
    harbor-bootstrapper = local.state.harbor_bootstrapper.node_exporter_targets.ips
    vault               = local.state.vault_pki.vault_node_exporter_targets.ips
  }
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
  minio_fqdn = local.state.vault_pki.global_pki_map["observability-minio"].dns_san[0]
  minio_port = local.state.minio_provision.minio_api_port
}

# Mimir External FQDN (derived from PKI map; startswith guards against base SANs)
locals {
  mimir_fqdn = [
    for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san :
    san if startswith(san, "mimir.")
  ][0]
}

# Loki External FQDN (derived from PKI map; same startswith pattern as mimir_fqdn above)
locals {
  loki_fqdn = [
    for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san :
    san if startswith(san, "loki.")
  ][0]
}

locals {
  credential_paths      = local.state.credentials.global_credential_paths
  s3_credentials_prefix = "${local.state.vault_pki.vault_kv_namespace}/observability/app/s3_credentials"
}

# Blackbox Probe Targets (derived from L00 global_pki_map; has_ingress marks components with a
# real external route, filtering out internal-only entries whose dns_san is non-empty only
# because of the unconditional internal mTLS SAN). Any future service that gains a real ingress
# block is picked up automatically, no change needed at this layer.
locals {
  blackbox_targets = concat(
    [
      for key, entry in local.state.vault_pki.global_pki_map : {
        name    = key
        address = "https://${entry.dns_san[0]}"
        module  = "http_2xx"
      } if entry.has_ingress
    ],
    local.state.provision.cross_route_probe_targets
  )
}
