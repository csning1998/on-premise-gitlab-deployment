
output "dev_harbor_ip" {
  description = "Dev Harbor IP."
  value       = [for node in var.dev_harbor_compute.dev_harbor_config.node : node.ip]
}
