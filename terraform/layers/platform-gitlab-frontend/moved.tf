
moved {
  from = kubernetes_manifest.observability_vault_secret_store
  to   = module.minio_metrics_token.kubernetes_manifest.observability_vault_secret_store
}

moved {
  from = kubernetes_manifest.minio_metrics_token_external_secret
  to   = module.minio_metrics_token.kubernetes_manifest.minio_metrics_token_external_secret
}
