
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
    metadata = data.terraform_remote_state.metadata.outputs
  }
}

locals {
  bootstrap_leaf_extra_domains = {
    "vault-frontend"      = ["vault", "localhost"]
    "central-lb-frontend" = []
  }

  bootstrap_leaf_roles = {
    for name, extras in local.bootstrap_leaf_extra_domains : name => {
      allowed_domains = concat(local.state.metadata.global_pki_map[name].dns_san, extras)
      ou              = local.state.metadata.global_pki_map[name].ou
    }
  }
}
