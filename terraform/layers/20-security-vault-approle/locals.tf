
# State Object
locals {
  state = {
    metadata           = data.terraform_remote_state.metadata.outputs
    vault_sys          = data.terraform_remote_state.vault_sys.outputs
    vault_bootstrapper = data.terraform_remote_state.vault_bootstrapper.outputs # Seed Vault is in Layer 00
  }

  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"
  ca_cert_path   = local.state.vault_sys.ca_cert_path
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
    "pki*"     = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    "secret/*" = { capabilities = ["create", "read", "update", "delete", "list"] }

    # Identity & Policies
    "identity/*"         = { capabilities = ["create", "read", "update", "delete", "list"] }
    "sys/policies/acl/*" = { capabilities = ["create", "update", "read", "delete", "list", "sudo"] }

    # System
    "sys/health" = { capabilities = ["read"] }
  }
}
