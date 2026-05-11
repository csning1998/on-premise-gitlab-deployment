
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
  # Extract unique authentication paths from metadata to ensure all provisioned
  # backends (AppRole and Kubernetes) are authorized.
  _all_auth_paths = distinct(concat(
    [for k, v in local.state.metadata.global_pki_map : v.auth_config.path],
    [for k, v in local.state.metadata.global_pki_map : v.auth_config.approle_path]
  ))

  # Dynamically generate administrative rules using valid Vault prefix wildcards.
  _auth_rules = {
    for path in local._all_auth_paths :
    "auth/${path}/*" => { capabilities = ["create", "read", "update", "delete", "list"] }
  }

  admin_policy_rules = merge(
    {
      # [1] Data Plane (Business Data): Maintain strict least privilege,
      #     precisely scoped to specific projects and mount points.
      "secret/data/on-premise-gitlab-deployment/*"     = { capabilities = ["create", "read", "update", "delete"] }
      "secret/metadata/on-premise-gitlab-deployment/*" = { capabilities = ["create", "read", "update", "delete", "list"] }
      "secret/delete/on-premise-gitlab-deployment/*"   = { capabilities = ["update"] }
      "secret/destroy/on-premise-gitlab-deployment/*"  = { capabilities = ["update"] }

      "pki/prod/*"                          = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
      "pki-infrastructure-root-bootstrap/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }

      # [2] Control Plane (Administrative): Complies with Terraform official IaC management requirements.
      #     Must allow global sys/mounts and sys/auth; otherwise, global routing table updates
      #     and cascading revocations during 'destroy' operations cannot be executed.
      "sys/mounts"   = { capabilities = ["read", "list"] }
      "sys/mounts/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }

      "sys/auth"   = { capabilities = ["read", "list"] }
      "sys/auth/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }

      # [3] Policy Management
      "sys/policies/acl/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
    },
    local._auth_rules
  )
}
