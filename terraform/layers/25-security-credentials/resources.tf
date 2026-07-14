
# Long-lived orphan token for Alloy's authenticated Vault metrics scrape, minted from the
# "alloy-metrics" token role (defined in 20-security-vault-approle). The role's orphan = true
# lets this non-root AppRole identity issue an orphan token without sudo, and its
# allowed_policies scopes it to the metrics-read policy. The token value itself is written to
# its own KV path by the resource below, then delivered to Alloy via ExternalSecret in
# L50 observability frontend, replacing unauthenticated_metrics_access.
resource "vault_token" "alloy_metrics" {
  provider  = vault.production
  role_name = data.terraform_remote_state.vault_prod_bootstrap.outputs.alloy_metrics_role_name
  policies  = [data.terraform_remote_state.vault_prod_bootstrap.outputs.alloy_metrics_policy_name]
  renewable = true
  ttl       = "${365 * 24}h" # 1 year
}

# Own KV path rather than bundled into observability_frontend's static credentials; a Vault auth
# role scoped only to this token therefore does not also gain read access to grafana_admin_user.
resource "vault_kv_secret_v2" "alloy_metrics_token" {
  provider = vault.production
  mount    = "secret"
  name     = "${local.vault_kv_namespace}/observability/app/vault_metrics_token"

  data_json = jsonencode({
    token = vault_token.alloy_metrics.client_token
  })
}
