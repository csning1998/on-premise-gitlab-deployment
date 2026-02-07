
output "dev_harbor_cluster_name" {
  description = "Dev Harbor cluster name."
  value       = local.cluster_name
}

output "dev_harbor_ip" {
  description = "Dev Harbor IP."
  value       = [for node in var.dev_harbor_compute.dev_harbor_system_config.node : node.ip]
}
