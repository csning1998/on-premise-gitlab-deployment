
# GitLab HTTP backend credentials (read at plan time from gitignored file)
locals {
  _gl_credentials = jsondecode(file("${path.root}/../../backend-state.json"))
  _state_base     = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
  _state_auth = {
    username = local._gl_credentials.username
    password = local._gl_credentials.token
  }
}

# State Object
locals {
  state = {
    vault_sys          = data.terraform_remote_state.vault_sys.outputs
    vault_bootstrapper = data.terraform_remote_state.vault_bootstrapper.outputs # Seed Vault is in Layer 00
  }

  sys_vault_endpoint = "https://${local.state.vault_sys.service_vip}:443"
  ca_cert_path       = local.state.vault_sys.ca_cert_path
}

locals {
  admin_policy_rules = {
    # Auth & Mounts
    "auth/*"       = { capabilities = ["create", "read", "update", "delete", "list"] }
    "sys/auth/*"   = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    "sys/auth"     = { capabilities = ["read", "list"] }
    "sys/mounts/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    "sys/mounts"   = { capabilities = ["read", "list"] }

    # PKI & Secrets
    "pki/prod/*"                          = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    "pki-infrastructure-root-bootstrap/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    "secret/*"                            = { capabilities = ["create", "read", "update", "delete", "list"] }

    # Identity & Policies
    "identity/*"         = { capabilities = ["create", "read", "update", "delete", "list"] }
    "sys/policies/acl/*" = { capabilities = ["create", "update", "read", "delete", "list", "sudo"] }

    # System
    "sys/health" = { capabilities = ["read"] }
  }
}
