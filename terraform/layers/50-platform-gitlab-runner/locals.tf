
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
    vault_pki               = data.terraform_remote_state.vault_pki.outputs
    vault_prod_bootstrap    = data.terraform_remote_state.vault_prod_bootstrap.outputs
    harbor_bootstrapper_oci = data.terraform_remote_state.harbor_bootstrapper_oci.outputs
    provision               = data.terraform_remote_state.provision.outputs
  }
}

# 2. K8s Provider Authentication Context
locals {
  kubeconfig_raw = yamldecode(base64decode(ephemeral.vault_kv_secret_v2.kubeconfig.data["content_b64"]))
  cluster_info   = element(local.kubeconfig_raw.clusters, 0).cluster
  user_info      = element(local.kubeconfig_raw.users, 0).user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }

  issuer_name = local.state.provision.issuer_name
  issuer_kind = local.state.provision.issuer_kind
}

# 3. Application Context
locals {
  pod_network_mtu = local.state.provision.network_context.global_network_mtu

  gitlab_frontend_fqdn     = local.state.vault_pki.global_pki_map["gitlab-frontend"].dns_san[0]
  harbor_bootstrapper_fqdn = local.state.vault_pki.global_pki_map["harbor-bootstrapper-frontend"].dns_san[0]

  harbor_registry     = local.harbor_bootstrapper_fqdn
  harbor_docker_proxy = local.state.harbor_bootstrapper_oci.proxy_caches["docker_hub"].project_name
  harbor_gitlab_proxy = local.state.harbor_bootstrapper_oci.proxy_caches["gitlab_com"].project_name
  harbor_k8s_proxy    = local.state.harbor_bootstrapper_oci.proxy_caches["k8s_io"].project_name
  helm_chart_project  = local.state.harbor_bootstrapper_oci.proxy_oci["helm_charts"].name

  vault_api_port = local.state.provision.network_context.vault_api_port
  vault_endpoint = "https://${local.state.vault_pki.vault_service_vip}:${local.vault_api_port}"
}

# 4. CA Bundle & mTLS Configuration
locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name
    content     = base64decode(local.state.vault_pki.bootstrap_ca_b64.content_b64)
  }
  mimir_fqdn             = [for san in local.state.vault_pki.global_pki_map["observability-frontend"].dns_san : san if startswith(san, "mimir.")][0]
  mimir_remote_write_url = "https://${local.mimir_fqdn}/api/v1/push"
}

# 5. Node Exporter Context
locals {
  node_exporter_port = local.state.provision.node_exporter_targets.port
  node_exporter_ips  = local.state.provision.node_exporter_targets.ips
}
