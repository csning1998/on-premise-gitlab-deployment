
resource "grafana_folder" "kubernetes" {
  uid   = "kubernetes"
  title = "Kubernetes"
}

resource "grafana_data_source" "mimir" {
  for_each = var.mimir_tenants

  type = "prometheus"
  name = "Mimir / ${each.value.display_name}"
  uid  = "mimir-${each.key}"
  url  = local.mimir_query_url

  http_headers = {
    "X-Scope-OrgID" = each.key
  }
}

resource "grafana_dashboard" "k8s_cluster_overview" {
  depends_on  = [grafana_data_source.mimir]
  folder      = grafana_folder.kubernetes.uid
  config_json = file("${path.module}/dashboards/k8s-cluster-overview.json")
}
