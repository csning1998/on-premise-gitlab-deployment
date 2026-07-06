
locals {
  loki_buckets = [for k, v in var.observability_minio_tenants : k if startswith(k, "loki-")]
}

resource "minio_iam_user" "loki_service" {
  name          = "loki-service-user"
  force_destroy = true
}

resource "minio_iam_service_account" "loki_service" {
  target_user = minio_iam_user.loki_service.name
}

resource "minio_iam_policy" "loki_service" {
  name = "loki-service-policy"
  policy = jsonencode({
    Version = "2012-10-17" # Ref: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_version.html
    Statement = flatten([
      for bucket in local.loki_buckets : [
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
          Resource = "arn:aws:s3:::${bucket}"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"]
          Resource = "arn:aws:s3:::${bucket}/*"
        }
      ]
    ])
  })
}

resource "minio_iam_user_policy_attachment" "loki_service" {
  user_name   = minio_iam_user.loki_service.name
  policy_name = minio_iam_policy.loki_service.name
}

resource "vault_kv_secret_v2" "loki_service_creds" {
  provider = vault.production
  mount    = "secret"
  name     = "${data.terraform_remote_state.vault_pki.outputs.vault_kv_namespace}/observability/app/s3_credentials/loki-service"

  data_json = jsonencode({
    bucket     = join(",", local.loki_buckets)
    access_key = minio_iam_service_account.loki_service.access_key
    secret_key = minio_iam_service_account.loki_service.secret_key
    endpoint   = local.minio_url
  })
}
