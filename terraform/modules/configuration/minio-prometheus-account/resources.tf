
# Dedicated identity for Prometheus/Alloy scraping, scoped to admin:Prometheus only.
# Least-privilege alternative to using MINIO_PROMETHEUS_AUTH_TYPE=public or the root account.
resource "minio_iam_user" "this" {
  name          = var.user_name
  force_destroy = true
}

resource "minio_iam_service_account" "this" {
  target_user = minio_iam_user.this.name
}

resource "minio_iam_policy" "this" {
  name = "${var.user_name}-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["admin:Prometheus"],
        Resource = "*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "this" {
  user_name   = minio_iam_user.this.name
  policy_name = minio_iam_policy.this.name
}

locals {
  # JWT shaped like mc admin prometheus generate's output. See documentation/en/architecture/observability-metrics-security.md.
  jwt_header = jsonencode({ alg = "HS512", typ = "JWT" })
  jwt_payload = jsonencode({
    iss = "prometheus"
    sub = minio_iam_service_account.this.access_key
    exp = 4899220000 # fixed, 2125-04-01, non-rotating secret pattern
  })

  jwt_header_b64  = replace(replace(replace(base64encode(local.jwt_header), "+", "-"), "/", "_"), "=", "")
  jwt_payload_b64 = replace(replace(replace(base64encode(local.jwt_payload), "+", "-"), "/", "_"), "=", "")

  jwt_signing_input = "${local.jwt_header_b64}.${local.jwt_payload_b64}"
  jwt               = "${local.jwt_signing_input}.${data.external.jwt_signature.result.signature}"
}

# Using HMAC-SHA512 signature via openssl since Terraform does not provide native HMAC function.
# Secret is passed via stdin instead of a file but is still briefly visible as an openssl argv.
# Refer to the architecture doc.
data "external" "jwt_signature" {
  program = ["bash", "${path.module}/scripts/sign-jwt.sh"]

  query = {
    secret        = minio_iam_service_account.this.secret_key
    signing_input = local.jwt_signing_input
  }
}

resource "vault_kv_secret_v2" "this" {
  provider = vault.production
  mount    = "secret"
  name     = var.vault_secret_path

  data_json = jsonencode({
    access_key   = minio_iam_service_account.this.access_key
    secret_key   = minio_iam_service_account.this.secret_key
    bearer_token = local.jwt
  })
}
