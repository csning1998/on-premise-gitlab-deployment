
output "kubeconfig_content" {
  description = "Raw content of the Kubeconfig file"
  value       = data.external.fetched_kubeconfig.result["content"]
  sensitive   = true
}
