
module "minio_metrics_token" {
  source     = "../../modules/configuration/minio-metrics-token-secret"
  depends_on = [kubernetes_namespace.observability]

  namespace_name        = kubernetes_namespace.observability.metadata[0].name
  vault_endpoint        = local.vault_endpoint
  vault_ca_bundle_b64   = local.state.vault_pki.bootstrap_ca_b64.content_b64
  vault_auth_mount_path = "kubernetes/harbor/frontend"
  vault_role_name       = "core-harbor-frontend-role"
  vault_kv_key          = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/harbor/app/minio_prometheus"
}
