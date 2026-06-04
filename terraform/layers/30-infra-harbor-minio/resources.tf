
resource "vault_approle_auth_backend_role_secret_id" "minio_agent" {
  provider  = vault.production
  backend   = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[module.context.svc_pki_role.key].auth_path
  role_name = data.terraform_remote_state.vault_pki.outputs.workload_identities_approle[module.context.svc_pki_role.key].role_name

  metadata = jsonencode({
    "source" = "terraform-layer-30-harbor-minio"
  })
}
