
output "proxy_caches" {
  description = "The Declared Harbor Projects for storing container images."
  value       = local.proxy_caches
}

output "service_vip" {
  description = "The virtual IP assigned to the Bootstrap Harbor service from Central LB topology."
  value       = data.terraform_remote_state.harbor_bootstrapper.outputs.service_vip
}
