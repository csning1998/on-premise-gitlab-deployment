
# 1. Establish Buckets
resource "minio_s3_bucket" "buckets" {
  for_each = var.minio_tenants
  bucket   = each.key
  acl      = "private"
}

# 2. Establish IAM User
resource "minio_iam_user" "users" {
  for_each      = var.minio_tenants
  name          = each.value.user_name
  force_destroy = true
}

# 3. Establish Service Account (This is the correct resource to generate keys)
resource "minio_iam_service_account" "keys" {
  for_each    = var.minio_tenants
  target_user = minio_iam_user.users[each.key].name
}

# 4. Define IAM Policy
resource "minio_iam_policy" "bucket_policies" {
  for_each = var.minio_tenants

  name = "${each.key}-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ],
        Resource = "arn:aws:s3:::${each.key}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ],
        Resource = "arn:aws:s3:::${each.key}/*"
      }
    ]
  })
}

# 5. Bind Policy
resource "minio_iam_user_policy_attachment" "attachments" {
  for_each = var.minio_tenants

  user_name   = minio_iam_user.users[each.key].name
  policy_name = minio_iam_policy.bucket_policies[each.key].name
}

# 6. Write credentials back to Vault
resource "vault_generic_secret" "s3_credentials" {
  for_each = var.minio_tenants

  path = "${var.vault_secret_path_prefix}/${each.key}"

  data_json = jsonencode({
    bucket = each.key

    access_key = minio_iam_service_account.keys[each.key].access_key
    secret_key = minio_iam_service_account.keys[each.key].secret_key
    endpoint   = var.minio_server_url
  })
}
