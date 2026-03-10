
# State Object
locals {
  state = {
    vault_pki = data.terraform_remote_state.vault_pki.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
  }

  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"
}

locals {
  proxy_caches = {
    docker_hub = {
      registry_name = "hub.docker.com"
      endpoint_url  = "https://hub.docker.com"
      provider_name = "docker-hub"
      project_name  = "docker-proxy"
    }
    k8s_io = {
      registry_name = "registry.k8s.io"
      endpoint_url  = "https://registry.k8s.io"
      provider_name = "docker-registry"
      project_name  = "k8s-proxy"
    }
    quay_io = {
      registry_name = "quay.io"
      endpoint_url  = "https://quay.io"
      provider_name = "docker-registry"
      project_name  = "quay-proxy"
    }
    gcr_io = {
      registry_name = "gcr.io"
      endpoint_url  = "https://gcr.io"
      provider_name = "docker-registry"
      project_name  = "gcr-proxy"
    }
  }
}
