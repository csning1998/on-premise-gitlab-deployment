
# Generates a long-lived orphan token for Alloy's authenticated Vault metrics scraping. The token is
# minted from the "alloy-metrics" role in L20 with `orphan = true` to allow non-root issuance without sudo,
# and is restricted to the metrics-read policy.
# The token is stored in a dedicated KV path and delivered to Alloy via ExternalSecret in L50.
resource "vault_token" "alloy_metrics" {
  provider  = vault.production
  role_name = data.terraform_remote_state.vault_prod_bootstrap.outputs.alloy_metrics_role_name
  policies  = [data.terraform_remote_state.vault_prod_bootstrap.outputs.alloy_metrics_policy_name]
  renewable = true
  ttl       = "${365 * 24}h" # 1 year
}

# Stored in a dedicated KV path instead of the bundled observability-frontend credentials.
# This ensures that a Vault auth role scoped to this token cannot access other sensitive credentials.
resource "vault_kv_secret_v2" "alloy_metrics_token" {
  provider = vault.production
  mount    = "secret"
  name     = "${local.vault_kv_namespace}/observability/app/vault_metrics_token"

  data_json = jsonencode({
    token = vault_token.alloy_metrics.client_token
  })
}

# Replicates `haproxy_stats_pass` from the Bootstrap Vault to the Production Vault, allowing
# retrieval by the Alloy ExternalSecret which lacks runtime access to the Bootstrap Vault.
data "vault_kv_secret_v2" "bootstrap_infrastructure" {
  provider = vault.bootstrap
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/infrastructure"
}

resource "vault_kv_secret_v2" "observability_haproxy_stats" {
  provider = vault.production
  mount    = "secret"
  name     = "${local.vault_kv_namespace}/observability/app/haproxy_stats"

  data_json = jsonencode({
    haproxy_stats_pass = data.vault_kv_secret_v2.bootstrap_infrastructure.data["haproxy_stats_pass"]
  })
}
