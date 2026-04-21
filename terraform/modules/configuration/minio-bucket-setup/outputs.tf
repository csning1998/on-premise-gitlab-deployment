
output "service_accounts" {
  description = "Credentials for each tenant service account"
  value = {
    for k, v in minio_iam_service_account.keys : k => {
      access_key = v.access_key
      secret_key = v.secret_key
    }
  }
  sensitive = true
}
