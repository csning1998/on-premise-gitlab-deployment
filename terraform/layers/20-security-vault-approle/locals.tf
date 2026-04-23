
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
  # Extract unique authentication paths from metadata to avoid duplicate key errors
  # during policy map construction (e.g., multiple baremetal components sharing 'workload-approle').
  _all_auth_paths = distinct([for k, v in local.state.metadata.global_pki_map : v.auth_config.path])

  # Dynamically generate administrative rules for all authentication backends defined in Metadata.
  _auth_rules = {
    for path in local._all_auth_paths :
    "auth/${path}/*" => { capabilities = ["create", "read", "update", "delete", "list"] }
  }

  admin_policy_rules = merge(
    {
      # [1] Data Plane (Business Data): Maintain strict least privilege,
      #     precisely scoped to specific projects and mount points.
      "secret/data/on-premise-gitlab-deployment/*"     = { capabilities = ["create", "read", "update", "delete"] }
      "secret/metadata/on-premise-gitlab-deployment/*" = { capabilities = ["read", "list", "delete"] }
      "secret/delete/on-premise-gitlab-deployment/*"   = { capabilities = ["update"] }
      "secret/destroy/on-premise-gitlab-deployment/*"  = { capabilities = ["update"] }

      "pki/prod/*" = { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }

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
