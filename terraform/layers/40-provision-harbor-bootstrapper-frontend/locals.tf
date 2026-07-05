
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_creds.username
    password = local._gl_creds.token
  }
}

locals {
  state = {
    vault_pki           = data.terraform_remote_state.vault_pki.outputs
    credentials         = data.terraform_remote_state.credentials.outputs
    harbor_bootstrapper = data.terraform_remote_state.harbor_bootstrapper.outputs
  }

  sys_vault_addr = "https://${local.state.vault_pki.vault_service_vip}:443"
}

locals {
  credential_paths = local.state.credentials.global_credential_paths
}

locals {
  ansible_extra_vars = {
    harbor_robot_user       = harbor_robot_account.helm_pusher.full_name
    harbor_registry         = local.state.harbor_bootstrapper.bstrap_harbor_fqdn
    harbor_project          = local.proxy_oci["helm_charts"].name
    vault_addr              = local.sys_vault_addr
    vault_approle_role_id   = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_role_id
    vault_approle_secret_id = data.terraform_remote_state.vault_prod_bootstrap.outputs.production_secret_id
  }

  ansible_config = {
    root_path       = abspath("${path.root}/../../../ansible")
    ssh_config_path = local.state.harbor_bootstrapper.ssh_config_file_path
    inventory_file  = "inventory-provision-harbor-bootstrapper-frontend.yaml"
  }

  # Re-wrap Layer 30 inventory into a specific group for L40 business logic
  inventory_data = {
    all = {
      children = {
        harbor_bootstrapper_oci = {
          hosts = {
            for k, v in local.state.harbor_bootstrapper.ansible_inventory.data.all.children.primary.hosts : k => merge(v, {
              node_role = "harbor_bootstrapper_oci"
            })
          }
        }
      }
    }
  }
}

locals {
  proxy_oci = {
    helm_charts = {
      name = "helm-charts"
    }
  }
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
    gitlab_com = {
      registry_name = "registry.gitlab.com"
      endpoint_url  = "https://registry.gitlab.com"
      provider_name = "docker-registry"
      project_name  = "gitlab-proxy"
    }
    gcr_io = {
      registry_name = "gcr.io"
      endpoint_url  = "https://gcr.io"
      provider_name = "docker-registry"
      project_name  = "gcr-proxy"
    }
    ghcr_io = {
      registry_name = "ghcr.io"
      endpoint_url  = "https://ghcr.io"
      provider_name = "docker-registry"
      project_name  = "ghcr-proxy"
    }
  }
}
