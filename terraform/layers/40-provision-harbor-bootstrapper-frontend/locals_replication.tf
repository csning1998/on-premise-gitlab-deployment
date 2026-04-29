
locals {
  external_registries = {
    registry_k8s_io = {
      name          = "oci-registry-k8s-io"
      endpoint_url  = "https://registry.k8s.io"
      provider_name = "docker-registry"
    }
    gitlab_registry = {
      name          = "oci-registry-gitlab"
      endpoint_url  = "https://registry.gitlab.com"
      provider_name = "gitlab"
    }
    quay_io = {
      name          = "oci-quay-io"
      endpoint_url  = "https://quay.io"
      provider_name = "quay"
    }
    ghcr_io = {
      name          = "oci-ghcr-io"
      endpoint_url  = "https://ghcr.io"
      provider_name = "github"
    }
    docker_hub = {
      name          = "oci-docker-hub"
      endpoint_url  = "https://registry-1.docker.io"
      provider_name = "docker-hub"
    }
  }

  replication_policies = {
    ingress_nginx = {
      registry_key  = "registry_k8s_io"
      resource_name = "ingress-nginx/ingress-nginx"
    }
    metrics_server = {
      registry_key  = "registry_k8s_io"
      resource_name = "metrics-server/metrics-server"
    }
    gitlab = {
      registry_key  = "gitlab_registry"
      resource_name = "gitlab-org/charts/gitlab"
    }
    cert_manager = {
      registry_key  = "quay_io"
      resource_name = "jetstack/charts/cert-manager"
    }
    tigera = {
      registry_key  = "quay_io"
      resource_name = "tigera/operator"
    }
    harbor = {
      registry_key  = "docker_hub"
      resource_name = "bitnamicharts/harbor"
    }
    local_path = {
      registry_key  = "ghcr_io"
      resource_name = "rancher/local-path-provisioner"
    }
  }
}
